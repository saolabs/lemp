#!/bin/bash

# Kiểm tra quyền root
if [ "$EUID" -ne 0 ]; then
  echo "Vui lòng chạy script này với quyền root hoặc sử dụng sudo."
  exit 1
fi

# Hàm hiển thị hướng dẫn sử dụng
usage() {
  echo "Usage: $0 [--nginx] [--apache] [--ssl] [--laravel] -name <config_name> -domain <domain_name> [-root <document_root>]"
  echo "  --nginx           : Tạo cấu hình cho Nginx (Mặc định)"
  echo "  --apache          : Chỉ tạo cấu hình cho Apache2 (Cổng 8080)"
  echo "  --ssl             : Sử dụng SSL với certbot"
  echo "  --laravel         : Kiểm tra document root và tự động thêm /public nếu chưa có"
  echo "  -name hoặc -n    : Tên file cấu hình (ví dụ: helloworld hay hello-world)"
  echo "  -domain hoặc -d  : Tên miền (có thể nhận nhiều -d làm server alias)"
  echo "  -root hoặc -r    : Đường dẫn root document (mặc định: /var/www/html/<config_name>)"
  exit 1
}

# Mặc định các giá trị
root=""
create_nginx=false
create_apache=false
use_ssl=false
laravel=false
domains=()

# Đọc các tham số đầu vào
while [[ "$#" -gt 0 ]]; do
  case $1 in
    --nginx) create_nginx=true ;;
    --apache) create_apache=true ;;
    --ssl) use_ssl=true ;;
    --laravel) laravel=true ;;
    -name|-n) name="$2"; shift ;;
    -domain|-d) domains+=("$2"); shift ;;
    -root|-r) root="$2"; shift ;;
    *) echo "Unknown parameter passed: $1"; usage ;;
  esac
  shift
  # Di chuyển sang tham số tiếp theo
done

# Nếu không chỉ định rõ, mặc định tạo cấu hình Nginx thuần (LEMP)
if [ "$create_nginx" = false ] && [ "$create_apache" = false ]; then
  create_nginx=true
fi

# Kiểm tra xem tên cấu hình và tên miền có được cung cấp không
if [[ -z "$name" || ${#domains[@]} -eq 0 ]]; then
  echo "Error: Missing required parameters -name and/or -domain"
  usage
fi

# Đường dẫn root document mặc định
if [[ -z "$root" ]]; then
  root="/var/www/html/$name"
elif [[ "$root" != /* ]]; then
  root="/var/www/html/$root"
fi

# Nếu là Laravel, thêm /public vào cuối đường dẫn root nếu chưa có
if [ "$laravel" = true ]; then
  if [[ "$root" != */public ]]; then
    root="$root/public"
  fi
fi

# Lấy phiên bản PHP hiện tại
if command -v php > /dev/null 2>&1; then
  php_version=$(php -r "echo PHP_MAJOR_VERSION.'.'.PHP_MINOR_VERSION;")
else
  php_version="8.3" # Giá trị dự phòng nếu PHP chưa cài đặt
fi

# Tạo danh sách các tên miền
domain_list="${domains[0]}"
for alias in "${domains[@]:1}"; do
  domain_list="$domain_list $alias"
done

# Tạo cấu hình cho Nginx nếu cần
if [ "$create_nginx" = true ]; then
  nginx_conf="/etc/nginx/sites-available/$name"
  {
    echo "server {"
    echo "    listen [::]:80;"
    echo "    listen 80;"
    echo ""
    echo "    # Root Document"
    echo "    root $root;"
    echo ""
    echo "    # Danh sách tệp mặc định"
    echo "    index index.php default.php index.html;"
    echo ""
    echo "    server_name $domain_list;"
    echo ""
    echo "    location ~* ^/(static/).+\.(?:css|cur|js|jpe?g|gif|htc|ico|png|html|xml|otf|ttf|eot|woff|woff2|svg)\$ {"
    echo "        try_files \$uri \$uri/ /index.php;"
    echo "        client_max_body_size 100M;"
    echo "        access_log off;"
    echo "        expires 30d;"
    echo "        add_header Cache-Control public;"
    echo "        tcp_nodelay off;"
    echo "        open_file_cache max=3000 inactive=120s;"
    echo "        open_file_cache_valid 45s;"
    echo "        open_file_cache_min_uses 2;"
    echo "        open_file_cache_errors off;"
    echo "    }"
    echo ""
    
    # Cấu hình route chính
    if [ "$create_apache" = true ]; then
      # Nếu cấu hình lai chạy với Apache, chuyển tiếp request tĩnh/động không xác định sang Apache cổng 8080
      echo "    location / {"
      echo "        fastcgi_read_timeout 3000;"
      echo "        proxy_read_timeout 3000;"
      echo "        proxy_connect_timeout 3000;"
      echo "        proxy_send_timeout 3000;"
      echo "        send_timeout 3000;"
      echo "        proxy_set_header X-Real-IP  \$remote_addr;"
      echo "        proxy_set_header X-Forwarded-For \$remote_addr;"
      echo "        proxy_set_header Host \$host;"
      echo "        proxy_set_header X-Forwarded-Proto \$scheme;"
      echo "        proxy_pass http://127.0.0.1:8080;"
      echo "        client_max_body_size 100M;"
      echo "    }"
    else
      # Nếu là Nginx thuần (LEMP), xử lý rewrite URL trực tiếp tại đây (Laravel/WordPress)
      echo "    location / {"
      echo "        try_files \$uri \$uri/ /index.php?\$query_string;"
      echo "        client_max_body_size 100M;"
      echo "    }"
    fi
    echo ""
    echo "    location ~ \.php\$ {"
    echo "        fastcgi_read_timeout 3000;"
    echo "        fastcgi_pass unix:/run/php/php${php_version}-fpm.sock;"
    echo "        include snippets/fastcgi-php.conf;"
    echo "        fastcgi_param SCRIPT_FILENAME \$document_root\$fastcgi_script_name;"
    echo "        include fastcgi_params;"
    echo "    }"
    echo ""
    echo "    location ~ /\.ht {"
    echo "        deny all;"
    echo "    }"
    echo ""
    # Phục vụ file tĩnh trực tiếp bởi Nginx (CSS, JS, fonts, images) - tăng hiệu năng cho Laravel/WordPress
    echo "    location ~* \.(?:css|js|jpe?g|png|gif|ico|svg|woff|woff2|ttf|eot|otf|webp|avif|mp4|webm)\$ {"
    echo "        expires 30d;"
    echo "        access_log off;"
    echo "        add_header Cache-Control \"public, immutable\";"
    echo "        try_files \$uri =404;"
    echo "    }"
    echo "}"
  } > "$nginx_conf"
  
  # Tạo liên kết tượng trưng sang sites-enabled một cách an toàn
  if [ ! -f "/etc/nginx/sites-enabled/$name" ]; then
    ln -sf "$nginx_conf" "/etc/nginx/sites-enabled/"
  fi
  echo "Nginx configuration created at $nginx_conf"
fi

# Tạo cấu hình cho Apache2 nếu cần
if [ "$create_apache" = true ]; then
  if ! command -v apache2 > /dev/null 2>&1; then
    echo "Error: Apache2 is not installed on this system. Please install it first or run without --apache."
    exit 1
  fi

  apache_conf="/etc/apache2/sites-available/$name.conf"
  {
    echo "<VirtualHost *:8080>"
    echo "    ServerName ${domains[0]}"
    for alias in "${domains[@]:1}"; do
      echo "    ServerAlias $alias"
    done
    echo "    DocumentRoot $root"
    echo "    <Directory $root>"
    echo "        Options FollowSymLinks"
    echo "        AllowOverride All"
    echo "        Require all granted"
    echo "    </Directory>"
    echo ""
    echo "    # Kết nối PHP-FPM thông qua mod_proxy_fcgi hiện đại"
    echo "    <FilesMatch \\.php$>"
    echo "        SetHandler \"proxy:unix:/run/php/php${php_version}-fpm.sock|fcgi://localhost\""
    echo "    </FilesMatch>"
    echo ""
    echo "    ErrorLog \${APACHE_LOG_DIR}/error.log"
    echo "    CustomLog \${APACHE_LOG_DIR}/access.log combined"
    echo "</VirtualHost>"
  } > "$apache_conf"
  a2ensite "$name.conf"
  echo "Apache2 configuration created at $apache_conf"
fi

# Tải lại dịch vụ Nginx
if [ "$create_nginx" = true ]; then
  systemctl reload nginx
fi

# Tải lại dịch vụ Apache2
if [ "$create_apache" = true ]; then
  systemctl reload apache2
fi

# Thiết lập chứng chỉ SSL với Certbot nếu được chỉ định
if [ "$use_ssl" = true ]; then
  domain_args=""
  for domain in "${domains[@]}"; do
    domain_args="$domain_args -d $domain"
  done

  # Sử dụng certbot tùy thuộc vào webserver tương ứng
  if [ "$create_apache" = true ] && [ "$create_nginx" = false ]; then
    certbot --apache $domain_args --non-interactive --agree-tos --register-unsafely-without-email
  else
    # Mặc định sử dụng Nginx để xác thực và thiết lập SSL
    certbot --nginx $domain_args --non-interactive --agree-tos --register-unsafely-without-email
  fi
fi

echo "Configuration for Nginx and/or Apache2 created and enabled."