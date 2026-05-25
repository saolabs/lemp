#!/bin/bash

# Kiểm tra quyền root
if [ "$EUID" -ne 0 ]; then
  echo "Vui lòng chạy script này với quyền root hoặc sử dụng sudo."
  exit 1
fi

# Bước 1: Cập nhật hệ thống và cài đặt các gói cần thiết
echo "Cập nhật hệ thống và cài đặt các gói cần thiết..."
sudo apt update
sudo apt install -y software-properties-common curl git unzip zip supervisor mysql-server nginx build-essential net-tools

# Thêm repository Ondrej PHP để luôn có các phiên bản PHP mới và ổn định
echo "Thêm repository Ondrej PHP..."
sudo add-apt-repository ppa:ondrej/php -y
sudo apt update

# Thiết lập phiên bản PHP mặc định cài đặt (ở đây chọn PHP 8.3 là phiên bản ổn định tiêu chuẩn)
PHP_VERSION="8.3"

echo "Cài đặt PHP $PHP_VERSION và các extension phổ biến..."
# Danh sách extension đầy đủ hỗ trợ Laravel + WordPress:
# - tokenizer, ctype, fileinfo: Laravel bắt buộc
# - imagick, exif: WordPress xử lý ảnh (crop, resize thumbnail)
# - redis: Cache driver phổ biến cho Laravel
sudo apt install -y php${PHP_VERSION} php${PHP_VERSION}-fpm php${PHP_VERSION}-cli php${PHP_VERSION}-mysql php${PHP_VERSION}-curl php${PHP_VERSION}-gd php${PHP_VERSION}-mbstring php${PHP_VERSION}-xml php${PHP_VERSION}-zip php${PHP_VERSION}-bcmath php${PHP_VERSION}-sqlite3 php${PHP_VERSION}-intl php${PHP_VERSION}-opcache php${PHP_VERSION}-tokenizer php${PHP_VERSION}-ctype php${PHP_VERSION}-fileinfo php${PHP_VERSION}-imagick php${PHP_VERSION}-exif php${PHP_VERSION}-redis

# Bước 2: Sửa đổi các file php.ini để tối ưu hiệu năng
echo "Sửa đổi các file php.ini..."
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

# Bước 3: Cấu hình Nginx mặc định (LEMP thuần)
echo "Cấu hình Nginx..."
sudo bash -c 'cat > /etc/nginx/sites-available/default << EOF
server {
    listen 80 default_server;
    listen [::]:80 default_server;

    root /var/www/html;

    # Thêm index.php vào danh sách các tệp tin mặc định
    index index.php index.html index.htm index.nginx-debian.html;

    server_name _;

    location ~* ^/(static/|wp-content/vcc|wp-admin/|wp-includes/).+\.(?:css|cur|js|jpe?g|gif|htc|ico|png|html|xml|otf|ttf|eot|woff|woff2|svg)\$ {
        try_files \$uri \$uri/ /index.php?\$query_string;
        client_max_body_size 100M;
        access_log off;
        expires 30d;
        add_header Cache-Control public;
        tcp_nodelay off;
        open_file_cache max=3000 inactive=120s;
        open_file_cache_valid 45s;
        open_file_cache_min_uses 2;
        open_file_cache_errors off;
    }

    location / {
        try_files \$uri \$uri/ /index.php?\$query_string;
        client_max_body_size 100M;
    }

    location ~ \.php\$ {
        fastcgi_read_timeout 3000;
        fastcgi_pass unix:/run/php/php'"$PHP_VERSION"'-fpm.sock;
        include snippets/fastcgi-php.conf;
        fastcgi_param SCRIPT_FILENAME \$document_root\$fastcgi_script_name;
        include fastcgi_params;
    }

    location ~ /\.ht {
        deny all;
    }
}
EOF'

# Khởi động lại Nginx
echo "Khởi động lại Nginx..."
sudo systemctl restart nginx

# Bước 4: Cài đặt Composer
echo "Cài đặt Composer..."
EXPECTED_CHECKSUM="$(php -r 'copy("https://composer.github.io/installer.sig", "php://stdout");')"
php -r "copy('https://getcomposer.org/installer', 'composer-setup.php');"
ACTUAL_CHECKSUM="$(php -r 'echo hash_file("sha384", "composer-setup.php");')"
if [ "$EXPECTED_CHECKSUM" != "$ACTUAL_CHECKSUM" ]; then
    echo 'ERROR: Invalid installer checksum' >&2
    rm composer-setup.php
    exit 1
fi
sudo php composer-setup.php --install-dir=/usr/local/bin --filename=composer
rm composer-setup.php

# Bước 5: Cài đặt Node.js LTS v20 từ NodeSource (Tránh bản cũ trong kho Ubuntu mặc định) và cài đặt PM2
echo "Cài đặt Node.js và PM2..."
curl -fsSL https://deb.nodesource.com/setup_20.x | sudo -E bash -
sudo apt install -y nodejs
sudo npm install -g pm2

# Bước 6: Cài đặt Certbot qua apt (Phù hợp cho cả Nginx cấu hình tự động)
echo "Cài đặt Certbot..."
sudo apt install -y certbot python3-certbot-nginx

# Bước 7: Khởi động lại các dịch vụ chính
echo "Khởi động lại Nginx và PHP-FPM..."
sudo systemctl restart nginx
sudo systemctl restart php${PHP_VERSION}-fpm

echo "Quá trình cài đặt và cấu hình hệ thống LEMP thuần đã hoàn tất thành công!"