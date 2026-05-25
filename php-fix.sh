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
if systemctl list-units --type=service | grep -q "php${PHP_VERSION}-fpm"; then
    sudo systemctl restart php${PHP_VERSION}-fpm
    echo "Đã khởi động lại php${PHP_VERSION}-fpm"
else
    echo "Không tìm thấy service php${PHP_VERSION}-fpm. Thử tìm các service fpm khác..."
    FPM_SERVICE=$(systemctl list-units --type=service --all | grep -oE "php[0-9.]+-fpm" | head -n 1)
    if [ -n "$FPM_SERVICE" ]; then
        sudo systemctl restart "$FPM_SERVICE"
        echo "Đã khởi động lại dịch vụ $FPM_SERVICE thay thế."
    fi
fi

echo "Sửa lỗi và kiểm tra hệ thống hoàn tất!"