#!/bin/bash

# Kiểm tra quyền root
if [ "$EUID" -ne 0 ]; then
  echo "Vui lòng chạy script này với quyền root hoặc sử dụng sudo."
  exit 1
fi

# Hàm hiển thị hướng dẫn sử dụng
usage() {
  echo "Usage: $0 [version]"
  echo "  version : Phiên bản PHP muốn cài đặt hoặc cập nhật (ví dụ: 8.3). Nếu bỏ trống, sẽ hỏi người dùng."
  exit 1
}

# Kiểm tra xem phiên bản PHP đã được cung cấp chưa
if [ -z "$1" ]; then
  if command -v php > /dev/null 2>&1; then
    read -p "Nhập phiên bản PHP bạn muốn cài đặt hoặc cập nhật (ví dụ: 8.3): " PHP_VERSION
  else
    read -p "Nhập phiên bản PHP bạn muốn cài đặt (bỏ trống để cài phiên bản mặc định - 8.3): " PHP_VERSION
    if [ -z "$PHP_VERSION" ]; then
      PHP_VERSION="8.3"
    fi
  fi
else
  PHP_VERSION="$1"
fi

# Loại bỏ ký tự khoảng trắng thừa
PHP_VERSION=$(echo "$PHP_VERSION" | xargs)

if [ -z "$PHP_VERSION" ]; then
  echo "Error: Phiên bản PHP không hợp lệ."
  exit 1
fi

# Hàm kiểm tra phiên bản PHP hiện tại
check_php_version() {
  if command -v php > /dev/null 2>&1; then
    CURRENT_PHP_VERSION=$(php -r 'echo PHP_MAJOR_VERSION.".".PHP_MINOR_VERSION;')
    echo "Phiên bản PHP hiện tại mặc định của CLI: $CURRENT_PHP_VERSION"
  else
    CURRENT_PHP_VERSION=""
    echo "Không có phiên bản PHP nào được cài đặt trên hệ thống."
  fi
}

# Cài đặt PHP mới (Chạy song song, không xóa phiên bản cũ để tránh sập hệ thống)
install_php() {
  echo "Cài đặt PHP $PHP_VERSION và các module cần thiết..."
  sudo add-apt-repository ppa:ondrej/php -y
  sudo apt update
  sudo apt install -y php$PHP_VERSION php$PHP_VERSION-fpm php$PHP_VERSION-cli php$PHP_VERSION-mysql php$PHP_VERSION-curl php$PHP_VERSION-gd php$PHP_VERSION-mbstring php$PHP_VERSION-xml php$PHP_VERSION-zip php$PHP_VERSION-bcmath php$PHP_VERSION-sqlite3 php$PHP_VERSION-intl php$PHP_VERSION-opcache php$PHP_VERSION-tokenizer php$PHP_VERSION-ctype php$PHP_VERSION-fileinfo php$PHP_VERSION-imagick php$PHP_VERSION-exif php$PHP_VERSION-redis php$PHP_VERSION-swoole
}

# Sửa đổi các file cấu hình
update_config_files() {
  echo "Cập nhật các file cấu hình..."
  
  # Sửa đổi các file php.ini
  PHP_INI_FILES=(
      "/etc/php/$PHP_VERSION/cli/php.ini"
      "/etc/php/$PHP_VERSION/fpm/php.ini"
      "/etc/php/$PHP_VERSION/apache2/php.ini"
  )
  for INI_FILE in "${PHP_INI_FILES[@]}"; do
      if [ -f "$INI_FILE" ]; then
          sudo sed -i 's/upload_max_filesize = .*/upload_max_filesize = 100M/' "$INI_FILE"
          sudo sed -i 's/post_max_size = .*/post_max_size = 100M/' "$INI_FILE"
          sudo sed -i 's/max_execution_time = .*/max_execution_time = 600/' "$INI_FILE"
          sudo sed -i 's/max_input_time = .*/max_input_time = 600/' "$INI_FILE"
          sudo sed -i 's/memory_limit = .*/memory_limit = 1G/' "$INI_FILE"
          echo "Sửa đổi cấu hình php.ini ($INI_FILE) cho PHP phiên bản $PHP_VERSION"
      fi
  done

  # Tối ưu OPcache cho production (giống lemp.sh)
  echo "Tối ưu cấu hình OPcache cho PHP $PHP_VERSION..."
  OPCACHE_INI="/etc/php/$PHP_VERSION/fpm/conf.d/10-opcache.ini"
  if [ -f "$OPCACHE_INI" ]; then
      sudo bash -c "cat > $OPCACHE_INI << 'OPCACHE_EOF'
[opcache]
opcache.enable=1
opcache.memory_consumption=256
opcache.interned_strings_buffer=16
opcache.max_accelerated_files=10000
opcache.revalidate_freq=0
opcache.validate_timestamps=1
opcache.save_comments=1
opcache.fast_shutdown=1
OPCACHE_EOF"
      echo "Đã tối ưu OPcache: 256MB bộ nhớ, 10000 file cache."
  fi

  # Tối ưu PHP-FPM pool cho production (giống lemp.sh)
  echo "Tối ưu PHP-FPM pool..."
  FPM_POOL="/etc/php/$PHP_VERSION/fpm/pool.d/www.conf"
  if [ -f "$FPM_POOL" ]; then
      sudo sed -i 's/^pm = .*/pm = dynamic/' "$FPM_POOL"
      sudo sed -i 's/^pm.max_children = .*/pm.max_children = 50/' "$FPM_POOL"
      sudo sed -i 's/^pm.start_servers = .*/pm.start_servers = 5/' "$FPM_POOL"
      sudo sed -i 's/^pm.min_spare_servers = .*/pm.min_spare_servers = 5/' "$FPM_POOL"
      sudo sed -i 's/^pm.max_spare_servers = .*/pm.max_spare_servers = 35/' "$FPM_POOL"
      sudo sed -i 's/^;pm.max_requests = .*/pm.max_requests = 500/' "$FPM_POOL"
      echo "Đã tối ưu PHP-FPM pool: dynamic, max 50 workers."
  fi

  # Đảm bảo phân quyền session directory
  echo "Kiểm tra quyền ghi session của PHP..."
  SESSION_DIR="/var/lib/php/sessions"
  if [ -d "$SESSION_DIR" ]; then
      sudo chown -R www-data:www-data "$SESSION_DIR"
      sudo chmod -R 733 "$SESSION_DIR"
      echo "Đã phân quyền thư mục session tại $SESSION_DIR"
  fi

  # Khởi động dịch vụ PHP-FPM mới
  sudo systemctl start php$PHP_VERSION-fpm
  sudo systemctl enable php$PHP_VERSION-fpm

  # Nếu có cấu hình Nginx, tiến hành cập nhật socket sang PHP mới
  if [ -d "/etc/nginx/sites-available/" ]; then
    echo "Cập nhật cấu hình Nginx trong thư mục /etc/nginx/sites-available/..."
    # Lấy danh sách các file cấu hình Nginx
    nginx_conf_files=("/etc/nginx/sites-available/"*)
    for file in "${nginx_conf_files[@]}"; do
      if [ -f "$file" ]; then
        if [ -n "$CURRENT_PHP_VERSION" ] && [ "$CURRENT_PHP_VERSION" != "$PHP_VERSION" ]; then
          sudo sed -i "s/php$CURRENT_PHP_VERSION-fpm\.sock/php${PHP_VERSION}-fpm.sock/g" "$file"
        fi
      fi
    done
    sudo systemctl restart nginx
  fi

  # Nếu có cài đặt Apache, cập nhật cấu hình Apache sang PHP-FPM mới
  if command -v apache2 > /dev/null 2>&1; then
    echo "Cập nhật cấu hình Apache..."
    for file in "/etc/apache2/sites-available/"*.conf "/etc/apache2/ports.conf" "/etc/apache2/mods-enabled/fastcgi.conf"; do
      if [ -f "$file" ]; then
        if [ -n "$CURRENT_PHP_VERSION" ] && [ "$CURRENT_PHP_VERSION" != "$PHP_VERSION" ]; then
          sudo sed -i "s/php$CURRENT_PHP_VERSION/php$PHP_VERSION/g" "$file"
        fi
      fi
    done

    # Vô hiệu hóa module php cũ và bật module php mới trong apache nếu cài mod_php
    if [ -n "$CURRENT_PHP_VERSION" ]; then
      if [ -f "/etc/apache2/mods-available/php$CURRENT_PHP_VERSION.load" ]; then
        sudo a2dismod php$CURRENT_PHP_VERSION > /dev/null 2>&1 || true
      fi
    fi
    if [ -f "/etc/apache2/mods-available/php$PHP_VERSION.load" ]; then
      sudo a2enmod php$PHP_VERSION > /dev/null 2>&1 || true
    fi
    sudo systemctl restart apache2
  fi

  # Cập nhật liên kết mặc định trong hệ thống (Alternatives) cho CLI
  echo "Cập nhật hệ thống update-alternatives cho PHP $PHP_VERSION..."
  sudo update-alternatives --set php /usr/bin/php$PHP_VERSION >/dev/null 2>&1 || true
  sudo update-alternatives --set phar /usr/bin/phar$PHP_VERSION >/dev/null 2>&1 || true
  sudo update-alternatives --set phar.phar /usr/bin/phar.phar$PHP_VERSION >/dev/null 2>&1 || true
  
  if [ -f "/usr/bin/phpize$PHP_VERSION" ]; then
    sudo update-alternatives --set phpize /usr/bin/phpize$PHP_VERSION >/dev/null 2>&1 || true
  fi
  if [ -f "/usr/bin/php-config$PHP_VERSION" ]; then
    sudo update-alternatives --set php-config /usr/bin/php-config$PHP_VERSION >/dev/null 2>&1 || true
  fi
  
  # Khởi động lại PHP-FPM
  sudo systemctl restart php$PHP_VERSION-fpm
}

# Kiểm tra phiên bản hiện tại
check_php_version

if [ -z "$CURRENT_PHP_VERSION" ]; then
  echo "Không có phiên bản PHP nào được cài đặt. Tiến hành cài đặt mới PHP $PHP_VERSION..."
  install_php
  update_config_files
else
  if [ "$PHP_VERSION" == "$CURRENT_PHP_VERSION" ]; then
    echo "Phiên bản yêu cầu ($PHP_VERSION) trùng với phiên bản hiện tại mặc định ($CURRENT_PHP_VERSION). Cập nhật tối ưu hóa cấu hình..."
    install_php # Đảm bảo cài đủ các extension cần thiết
    update_config_files
  else
    echo "Cài đặt thêm phiên bản PHP $PHP_VERSION chạy song song (Phiên bản mặc định cũ: $CURRENT_PHP_VERSION)..."
    install_php
    update_config_files
  fi
fi

# Hiển thị phiên bản PHP hiện tại sau khi chạy xong
php -v

echo "Quá trình cài đặt hoặc cập nhật PHP $PHP_VERSION đã hoàn tất!"