#!/bin/bash

# Kiểm tra quyền root
if [ "$EUID" -ne 0 ]; then
  echo "Vui lòng chạy script này với quyền root hoặc sử dụng sudo."
  exit 1
fi

echo "Bắt đầu tiến trình cập nhật và dọn dẹp hệ thống..."
echo "Lưu ý: Nginx, Apache2, MySQL sẽ KHÔNG bị gỡ cài đặt để đảm bảo an toàn cho dữ liệu và web cũ."
sleep 2

# Bước 1: Cập nhật danh sách gói và thêm repo Ondrej PHP
echo "Thêm repository Ondrej PHP để cập nhật PHP..."
sudo apt update
sudo apt install -y software-properties-common curl git unzip zip
sudo add-apt-repository ppa:ondrej/php -y
sudo apt update

# Bước 2: Cài đặt PHP 8.3 và các extension mới nhất (Giữ nguyên PHP cũ)
PHP_VERSION="8.3"
echo "Cài đặt PHP $PHP_VERSION và các extension phổ biến cho kiến trúc mới..."
sudo apt install -y php${PHP_VERSION} php${PHP_VERSION}-fpm php${PHP_VERSION}-cli php${PHP_VERSION}-mysql php${PHP_VERSION}-curl php${PHP_VERSION}-gd php${PHP_VERSION}-mbstring php${PHP_VERSION}-xml php${PHP_VERSION}-zip php${PHP_VERSION}-bcmath php${PHP_VERSION}-sqlite3 php${PHP_VERSION}-intl php${PHP_VERSION}-opcache php${PHP_VERSION}-tokenizer php${PHP_VERSION}-ctype php${PHP_VERSION}-fileinfo php${PHP_VERSION}-imagick php${PHP_VERSION}-exif php${PHP_VERSION}-redis php${PHP_VERSION}-swoole

# Bước 3: Áp dụng các tối ưu hóa PHP mới (giống lemp.sh mới)
echo "Sửa đổi các file php.ini cho PHP $PHP_VERSION..."
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
    fi
done

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
fi

echo "Tối ưu PHP-FPM pool..."
FPM_POOL="/etc/php/$PHP_VERSION/fpm/pool.d/www.conf"
if [ -f "$FPM_POOL" ]; then
    sudo sed -i 's/^pm = .*/pm = dynamic/' "$FPM_POOL"
    sudo sed -i 's/^pm.max_children = .*/pm.max_children = 50/' "$FPM_POOL"
    sudo sed -i 's/^pm.start_servers = .*/pm.start_servers = 5/' "$FPM_POOL"
    sudo sed -i 's/^pm.min_spare_servers = .*/pm.min_spare_servers = 5/' "$FPM_POOL"
    sudo sed -i 's/^pm.max_spare_servers = .*/pm.max_spare_servers = 35/' "$FPM_POOL"
    sudo sed -i 's/^;pm.max_requests = .*/pm.max_requests = 500/' "$FPM_POOL"
fi

# Bước 4: Thêm cấu hình tối ưu Nginx (Không ghi đè Nginx site default cũ)
echo "Tối ưu cấu hình Nginx toàn cục (Gzip + Security Headers)..."
# Tránh lỗi duplicate directive gzip (áp dụng cho tất cả các thiết lập gzip hiện có)
sudo sed -i 's/^\s*gzip/# &/' /etc/nginx/nginx.conf

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

# === FILE UPLOAD LIMIT ===
client_max_body_size 100M;
OPTEOF'

# Bước 5: Cập nhật Node.js LTS v20
echo "Cài đặt Node.js v20 (thay thế bản cũ nếu có)..."
curl -fsSL https://deb.nodesource.com/setup_20.x | sudo -E bash -
sudo apt install -y nodejs
sudo npm install -g pm2

# Bước 6: Xử lý dọn dẹp các mục dư thừa
echo "Gỡ bỏ certbot cài bằng snap (nếu có) và thay bằng bản apt ổn định..."
sudo snap remove certbot 2>/dev/null || true
sudo apt install -y certbot python3-certbot-nginx

echo "Dọn dẹp các thư viện không còn dùng đến..."
sudo apt autoremove -y

# Bước 7: Khởi động lại dịch vụ
echo "Khởi động lại các dịch vụ..."
sudo systemctl restart nginx
sudo systemctl restart php${PHP_VERSION}-fpm
# Vẫn khởi động lại apache2 để đảm bảo các site cũ dùng apache port 8080 vẫn sống
sudo systemctl restart apache2 2>/dev/null || true

echo ""
echo "================================================================="
echo "🎉 CẬP NHẬT HOÀN TẤT!"
echo "Hệ thống đã được bổ sung PHP $PHP_VERSION, cấu hình tối ưu mới,"
echo "nhưng Apache2, Nginx, MySQL và dữ liệu cũ vẫn giữ nguyên."
echo "================================================================="
echo ""
echo "=== HƯỚNG DẪN CẬP NHẬT NGINX SITE CONFIG (TÙY CHỌN) ==="
echo "Các web cũ hiện đang chạy qua Nginx (port 80) -> Apache2 (port 8080) -> PHP."
echo "Nếu bạn muốn nâng cấp một web cũ sang chuẩn 'Nginx thuần' (bỏ qua Apache)"
echo "để có tốc độ cao hơn, hãy làm như sau:"
echo ""
echo "1. Mở file cấu hình Nginx của site (VD: /etc/nginx/sites-available/ten-site)"
echo "2. Tìm đoạn cấu hình proxy cũ:"
echo "   location / {"
echo "       proxy_pass http://127.0.0.1:8080;"
echo "       ..."
echo "   }"
echo ""
echo "3. Xóa đoạn proxy trên và thay bằng cấu hình PHP-FPM mới:"
echo "   location / {"
echo "       try_files \$uri \$uri/ /index.php?\$query_string;"
echo "   }"
echo "   location ~ \.php\$ {"
echo "       fastcgi_read_timeout 3000;"
echo "       fastcgi_pass unix:/run/php/php${PHP_VERSION}-fpm.sock;"
echo "       include snippets/fastcgi-php.conf;"
echo "       fastcgi_param SCRIPT_FILENAME \$document_root\$fastcgi_script_name;"
echo "       include fastcgi_params;"
echo "   }"
echo ""
echo "4. Lưu file và tải lại Nginx:"
echo "   sudo nginx -t && sudo systemctl reload nginx"
echo "================================================================="
