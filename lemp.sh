#!/bin/bash

# Kiểm tra quyền root
if [ "$EUID" -ne 0 ]; then
  echo "Vui lòng chạy script này với quyền root hoặc sử dụng sudo."
  exit 1
fi

# Bước 1: Cập nhật hệ thống và cài đặt các gói cần thiết
echo "Cập nhật hệ thống và cài đặt các gói cần thiết..."
sudo apt update
sudo apt install -y software-properties-common curl git unzip zip supervisor mysql-server nginx build-essential net-tools rsync

# Thêm repository Ondrej PHP để luôn có các phiên bản PHP mới và ổn định
echo "Thêm repository Ondrej PHP..."
sudo add-apt-repository ppa:ondrej/php -y
sudo apt update

# Thiết lập phiên bản PHP mặc định cài đặt (ở đây chọn PHP 8.3 là phiên bản ổn định tiêu chuẩn)
PHP_VERSION="8.3"

echo "Cài đặt PHP $PHP_VERSION và các extension phổ biến..."
# Danh sách extension đầy đủ hỗ trợ Laravel + WordPress + Octane:
# - tokenizer, ctype, fileinfo: Laravel bắt buộc
# - imagick, exif: WordPress xử lý ảnh (crop, resize thumbnail)
# - redis: Cache driver phổ biến cho Laravel
# - swoole: Laravel Octane high-performance server
sudo apt install -y php${PHP_VERSION} php${PHP_VERSION}-fpm php${PHP_VERSION}-cli php${PHP_VERSION}-mysql php${PHP_VERSION}-curl php${PHP_VERSION}-gd php${PHP_VERSION}-mbstring php${PHP_VERSION}-xml php${PHP_VERSION}-zip php${PHP_VERSION}-bcmath php${PHP_VERSION}-sqlite3 php${PHP_VERSION}-intl php${PHP_VERSION}-opcache php${PHP_VERSION}-tokenizer php${PHP_VERSION}-ctype php${PHP_VERSION}-fileinfo php${PHP_VERSION}-imagick php${PHP_VERSION}-exif php${PHP_VERSION}-redis php${PHP_VERSION}-swoole

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

# Bước 2b: Tối ưu OPcache cho production (Laravel/WordPress có hàng nghìn file PHP)
echo "Tối ưu cấu hình OPcache..."
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

# Bước 2c: Tối ưu PHP-FPM pool cho production
echo "Tối ưu PHP-FPM pool..."
FPM_POOL="/etc/php/$PHP_VERSION/fpm/pool.d/www.conf"
if [ -f "$FPM_POOL" ]; then
    # Chuyển sang dynamic process manager để tự điều chỉnh số tiến trình theo tải
    sudo sed -i 's/^pm = .*/pm = dynamic/' "$FPM_POOL"
    sudo sed -i 's/^pm.max_children = .*/pm.max_children = 50/' "$FPM_POOL"
    sudo sed -i 's/^pm.start_servers = .*/pm.start_servers = 5/' "$FPM_POOL"
    sudo sed -i 's/^pm.min_spare_servers = .*/pm.min_spare_servers = 5/' "$FPM_POOL"
    sudo sed -i 's/^pm.max_spare_servers = .*/pm.max_spare_servers = 35/' "$FPM_POOL"
    # Tự động khởi động lại worker sau 500 request để tránh rò rỉ bộ nhớ
    sudo sed -i 's/^;pm.max_requests = .*/pm.max_requests = 500/' "$FPM_POOL"
    echo "Đã tối ưu PHP-FPM pool: dynamic, max 50 workers."
fi

# Bước 3: Bật Gzip compression + Security Headers trong Nginx
echo "Tối ưu cấu hình Nginx toàn cục (Gzip + Security Headers)..."
sudo bash -c 'cat > /etc/nginx/conf.d/optimization.conf << OPTEOF
# === GZIP COMPRESSION ===
gzip on;
gzip_vary on;
gzip_proxied any;
gzip_comp_level 6;
gzip_min_length 256;
gzip_types
    text/plain
    text/css
    text/xml
    text/javascript
    application/json
    application/javascript
    application/xml
    application/rss+xml
    application/atom+xml
    application/vnd.ms-fontobject
    font/opentype
    font/ttf
    image/svg+xml;

# === SECURITY HEADERS ===
add_header X-Frame-Options "SAMEORIGIN" always;
add_header X-Content-Type-Options "nosniff" always;
add_header X-XSS-Protection "1; mode=block" always;
add_header Referrer-Policy "strict-origin-when-cross-origin" always;

# === FILE UPLOAD LIMIT (Toàn cục) ===
client_max_body_size 100M;
OPTEOF'

# Bước 3b: Cấu hình Nginx default site (LEMP thuần)
echo "Cấu hình Nginx default site..."
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
        fastcgi_buffer_size 128k;
        fastcgi_buffers 4 256k;
        fastcgi_busy_buffers_size 256k;
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
echo ""
echo "=== Hướng dẫn tiếp theo ==="
echo "1. Tạo VirtualHost:       sudo ./phpsv-config.sh --ssl -name myapp -d myapp.com"
echo "2. Laravel + Octane:     sudo ./phpsv-config.sh --laravel --octane --ssl -name myapp -d myapp.com"
echo "3. Deploy từ Git:        sudo ./gcp.sh https://github.com/user/repo.git myapp --laravel"
echo "4. Cài đặt WordPress:     sudo ./wp.sh --name myblog --domain myblog.com"