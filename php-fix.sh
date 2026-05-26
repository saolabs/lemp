#!/bin/bash

# Kiểm tra quyền root
if [ "$EUID" -ne 0 ]; then
  echo "Vui lòng chạy script này với quyền root hoặc sử dụng sudo."
  exit 1
fi

echo "Bắt đầu kiểm tra và sửa lỗi cấu hình PHP & Nginx..."

# Bước 1: Sửa đổi các file php.ini để đảm bảo thông số tối ưu
echo "Đang cấu hình tối ưu php.ini..."
if command -v php > /dev/null 2>&1; then
  PHP_VERSION=$(php -r 'echo PHP_MAJOR_VERSION.".".PHP_MINOR_VERSION;')
  PHP_INI_FILES=(
      "/etc/php/$PHP_VERSION/cli/php.ini"
      "/etc/php/$PHP_VERSION/fpm/php.ini"
  )
  for INI_FILE in "${PHP_INI_FILES[@]}"; do
      if [ -f "$INI_FILE" ]; then
          sudo sed -i 's/upload_max_filesize = .*/upload_max_filesize = 100M/' "$INI_FILE"
          sudo sed -i 's/post_max_size = .*/post_max_size = 100M/' "$INI_FILE"
          sudo sed -i 's/max_execution_time = .*/max_execution_time = 600/' "$INI_FILE"
          sudo sed -i 's/memory_limit = .*/memory_limit = 1G/' "$INI_FILE"
          echo "Sửa đổi cấu hình php.ini ($INI_FILE) cho PHP phiên bản $PHP_VERSION"
      else
          echo "Không tìm thấy file php.ini tại $INI_FILE"
      fi
  done

  # Khôi phục tối ưu OPcache cho production (giống lemp.sh)
  echo "Khôi phục cấu hình tối ưu OPcache..."
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
      echo "Đã khôi phục tối ưu OPcache: 256MB bộ nhớ, 10000 file cache."
  fi

  # Khôi phục tối ưu PHP-FPM pool cho production (giống lemp.sh)
  echo "Khôi phục cấu hình PHP-FPM pool..."
  FPM_POOL="/etc/php/$PHP_VERSION/fpm/pool.d/www.conf"
  if [ -f "$FPM_POOL" ]; then
      sudo sed -i 's/^pm = .*/pm = dynamic/' "$FPM_POOL"
      sudo sed -i 's/^pm.max_children = .*/pm.max_children = 50/' "$FPM_POOL"
      sudo sed -i 's/^pm.start_servers = .*/pm.start_servers = 5/' "$FPM_POOL"
      sudo sed -i 's/^pm.min_spare_servers = .*/pm.min_spare_servers = 5/' "$FPM_POOL"
      sudo sed -i 's/^pm.max_spare_servers = .*/pm.max_spare_servers = 35/' "$FPM_POOL"
      sudo sed -i 's/^;pm.max_requests = .*/pm.max_requests = 500/' "$FPM_POOL"
      echo "Đã khôi phục tối ưu PHP-FPM pool: dynamic, max 50 workers."
  fi
else
  echo "Lỗi: Không tìm thấy cài đặt PHP trên hệ thống."
  exit 1
fi

# Bước 2: Sửa lỗi phân quyền thư mục session của PHP (nếu có lỗi ghi session)
echo "Kiểm tra quyền ghi session của PHP..."
SESSION_DIR="/var/lib/php/sessions"
if [ -d "$SESSION_DIR" ]; then
    sudo chown -R www-data:www-data "$SESSION_DIR"
    sudo chmod -R 733 "$SESSION_DIR"
    echo "Đã phân lại quyền thư mục session tại $SESSION_DIR"
fi

# Bước 3: Kiểm tra cấu hình Nginx
echo "Kiểm tra cú pháp cấu hình Nginx..."
if nginx -t > /dev/null 2>&1; then
    echo "Cú pháp Nginx hợp lệ. Khởi động lại dịch vụ..."
    sudo systemctl restart nginx
else
    echo "Cảnh báo: Cú pháp Nginx bị lỗi. Vui lòng chạy lệnh 'nginx -t' để kiểm tra chi tiết."
fi

# Bước 4: Khởi động lại dịch vụ PHP-FPM
echo "Khởi động lại PHP-FPM..."
FPM_SERVICE="php${PHP_VERSION}-fpm"
if systemctl list-units --type=service | grep -q "${FPM_SERVICE}"; then
    sudo systemctl restart "${FPM_SERVICE}"
    echo "Đã khởi động lại ${FPM_SERVICE}"
else
    echo "Không tìm thấy service ${FPM_SERVICE}. Thử tìm các service fpm khác..."
    FPM_SERVICE=$(systemctl list-units --type=service --all | grep -oE "php[0-9.]+-fpm" | head -n 1)
    if [ -n "$FPM_SERVICE" ]; then
        sudo systemctl restart "$FPM_SERVICE"
        echo "Đã khởi động lại dịch vụ $FPM_SERVICE thay thế."
    fi
fi

# Bước 5: Kiểm tra trạng thái thực tế của các dịch vụ sau khi restart
echo "Đang kiểm tra trạng thái hoạt động của các dịch vụ..."
for SERVICE in "nginx" "$FPM_SERVICE"; do
    if [ -n "$SERVICE" ]; then
        if systemctl is-active --quiet "$SERVICE"; then
            echo "  - Dịch vụ $SERVICE: ĐANG CHẠY (Active)"
        else
            echo "  - Cảnh báo: Dịch vụ $SERVICE: KHÔNG HOẠT ĐỘNG (Inactive)"
        fi
    fi
done

echo "Sửa lỗi và kiểm tra hệ thống hoàn tất!"