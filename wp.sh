#!/bin/bash

# Kiểm tra quyền root
if [ "$EUID" -ne 0 ]; then
  echo "Vui lòng chạy script này với quyền root hoặc sử dụng sudo."
  exit 1
fi

# Hàm hiển thị hướng dẫn sử dụng
function show_help {
    echo "Usage:"
    echo "  $0 --name <folder_name> --domain <domain_name> [options]"
    echo "  $0 <folder_name> <domain_name> [options]"
    echo "Options:"
    echo "  -n | --name        Tên thư mục chứa WordPress (Document Root)"
    echo "  -d | --domain      Tên miền (domain) của website"
    echo "  --db-name          Tên cơ sở dữ liệu (tùy chọn)"
    echo "  --db-user          Tên người dùng cơ sở dữ liệu (tùy chọn)"
    echo "  --db-pass          Mật khẩu cơ sở dữ liệu (tùy chọn)"
    echo "  --db-admin         Tên quản trị viên cơ sở dữ liệu để tự động tạo database (tùy chọn, mặc định: root)"
    echo "  --db-admin-pass    Mật khẩu quản trị viên cơ sở dữ liệu (tùy chọn)"
    echo "  --create-db | --create-database | --cagdb"
    echo "                     Bật tính năng tự động tạo database và user MySQL"
    exit 1
}

# Nếu không có đủ tham số
if [ "$#" -lt 2 ]; then
    show_help
fi

# Mặc định không có giá trị
wp_folder=""
domain_name=""
wp_db=""
wp_user=""
wp_password=""
db_admin=""
db_admin_pass=""
create_db="false"

# Kiểm tra nếu tham số được truyền theo cờ
while [[ "$#" -gt 0 ]]; do
    case $1 in
        -n|--name) wp_folder="$2"; shift ;;
        -d|--domain) domain_name="$2"; shift ;;
        --db-name|--dbname) wp_db="$2"; shift ;;
        --db-user|--dbuser) wp_user="$2"; shift ;;
        --db-pass|--dbpass) wp_password="$2"; shift ;;
        --db-admin|--dbadmin) db_admin="$2"; shift ;;
        --db-admin-pass) db_admin_pass="$2"; shift ;;
        --create-db|--create-database|--cagdb) create_db="true" ;;
        *) 
            # Nếu tham số không dùng cờ, kiểm tra nếu đã có đủ 2 giá trị
            if [ -z "$wp_folder" ]; then
                wp_folder="$1"
            elif [ -z "$domain_name" ]; then
                domain_name="$1"
            else
                echo "Tham số không hợp lệ: $1"
                show_help
            fi
            ;;
    esac
    shift
done

# Kiểm tra nếu cả wp_folder và domain_name chưa được cung cấp
if [[ -z "$wp_folder" || -z "$domain_name" ]]; then
    echo "Thiếu tham số. Bạn cần chỉ định cả tên thư mục và tên miền."
    show_help
fi

# Kiểm tra xem thư mục đã tồn tại chưa để tránh ghi đè/lỗi di chuyển
if [ -d "/var/www/html/$wp_folder" ]; then
    echo "Lỗi: Thư mục /var/www/html/$wp_folder đã tồn tại trên hệ thống!"
    exit 1
fi

# Nhận thông tin cấu hình database cho WordPress
if [ -z "$wp_db" ]; then
    echo "Nhập tên database cho WordPress:"
    read -r wp_db
fi
if [ -z "$wp_user" ]; then
    echo "Nhập tên user cho database:"
    read -r wp_user
fi
if [ -z "$wp_password" ]; then
    echo "Nhập mật khẩu cho user:"
    read -r wp_password
fi

# Chỉ tự động khởi tạo database và user MySQL nếu có cờ --create-db/--create-database/--cagdb
if [ "$create_db" = "true" ]; then
    if [ -z "$db_admin" ]; then
        db_admin="root"
    fi

    echo "Đang khởi tạo database và user MySQL bằng tài khoản admin '$db_admin'..."

    if [ -n "$db_admin_pass" ]; then
        export MYSQL_PWD="$db_admin_pass"
    fi

    if [ "$db_admin" = "root" ]; then
        if [ -z "$db_admin_pass" ]; then
            sudo mysql -u root -p <<MYSQL_SCRIPT
CREATE DATABASE IF NOT EXISTS \`${wp_db}\` CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci;
CREATE USER IF NOT EXISTS '${wp_user}'@'localhost' IDENTIFIED BY '${wp_password}';
GRANT ALL PRIVILEGES ON \`${wp_db}\`.* TO '${wp_user}'@'localhost';
FLUSH PRIVILEGES;
MYSQL_SCRIPT
        else
            sudo MYSQL_PWD="$db_admin_pass" mysql -u root <<MYSQL_SCRIPT
CREATE DATABASE IF NOT EXISTS \`${wp_db}\` CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci;
CREATE USER IF NOT EXISTS '${wp_user}'@'localhost' IDENTIFIED BY '${wp_password}';
GRANT ALL PRIVILEGES ON \`${wp_db}\`.* TO '${wp_user}'@'localhost';
FLUSH PRIVILEGES;
MYSQL_SCRIPT
        fi
    else
        if [ -z "$db_admin_pass" ]; then
            mysql -u "$db_admin" -p <<MYSQL_SCRIPT
CREATE DATABASE IF NOT EXISTS \`${wp_db}\` CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci;
CREATE USER IF NOT EXISTS '${wp_user}'@'localhost' IDENTIFIED BY '${wp_password}';
GRANT ALL PRIVILEGES ON \`${wp_db}\`.* TO '${wp_user}'@'localhost';
FLUSH PRIVILEGES;
MYSQL_SCRIPT
        else
            mysql -u "$db_admin" <<MYSQL_SCRIPT
CREATE DATABASE IF NOT EXISTS \`${wp_db}\` CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci;
CREATE USER IF NOT EXISTS '${wp_user}'@'localhost' IDENTIFIED BY '${wp_password}';
GRANT ALL PRIVILEGES ON \`${wp_db}\`.* TO '${wp_user}'@'localhost';
FLUSH PRIVILEGES;
MYSQL_SCRIPT
        fi
    fi

    mysql_status=$?
    if [ -n "$db_admin_pass" ]; then
        unset MYSQL_PWD
    fi

    if [ $mysql_status -eq 0 ]; then
        echo "Database và user đã được tạo thành công."
    else
        echo "Lỗi khi tạo database. Vui lòng kiểm tra quyền truy cập MySQL."
        exit 1
    fi
else
    echo "Bỏ qua bước khởi tạo database và user MySQL (không yêu cầu bằng cờ --create-db/--create-database/--cagdb)."
fi

# Tải xuống và cài đặt WordPress
cd /var/www/html/ || exit 1

echo "Đang tải xuống phiên bản WordPress mới nhất..."
if ! sudo curl -L -O https://wordpress.org/latest.tar.gz; then
    echo "Lỗi: Tải xuống gói cài đặt WordPress thất bại."
    exit 1
fi

echo "Đang giải nén..."
if ! sudo tar -zxvf latest.tar.gz; then
    echo "Lỗi: Giải nén gói cài đặt WordPress thất bại."
    sudo rm -f latest.tar.gz
    exit 1
fi

# Dọn dẹp tệp tin tải về ngay sau khi giải nén thành công
sudo rm -f latest.tar.gz

echo "Cấu hình thư mục cài đặt..."
sudo mv wordpress "$wp_folder"

# Tạo và cấu hình file wp-config.php
WP_PATH="/var/www/html/$wp_folder"
WP_CONFIG_FILE="$WP_PATH/wp-config.php"
WP_SAMPLE_FILE="$WP_PATH/wp-config-sample.php"
WP_EXAMPLE_FILE="$WP_PATH/wp-config-example.php"

if [ -f "$WP_SAMPLE_FILE" ]; then
    echo "Tạo wp-config.php từ wp-config-sample.php..."
    sudo cp "$WP_SAMPLE_FILE" "$WP_CONFIG_FILE"
elif [ -f "$WP_EXAMPLE_FILE" ]; then
    echo "Tạo wp-config.php từ wp-config-example.php..."
    sudo cp "$WP_EXAMPLE_FILE" "$WP_CONFIG_FILE"
else
    echo "Cảnh báo: Không tìm thấy file wp-config-sample.php hoặc wp-config-example.php!"
fi

if [ -f "$WP_CONFIG_FILE" ]; then
    echo "Cập nhật thông tin cấu hình database trong wp-config.php..."
    sudo sed -i "s|database_name_here|$wp_db|g" "$WP_CONFIG_FILE"
    sudo sed -i "s|username_here|$wp_user|g" "$WP_CONFIG_FILE"
    sudo sed -i "s|password_here|$wp_password|g" "$WP_CONFIG_FILE"

    echo "Đang tải các khóa bảo mật (salts) từ api.wordpress.org..."
    SALTS=$(curl -s --max-time 10 https://api.wordpress.org/secret-key/1.1/salt/)
    if [ -n "$SALTS" ] && echo "$SALTS" | grep -q "AUTH_KEY"; then
        echo "Cập nhật các khóa bảo mật vào wp-config.php..."
        sudo SALTS_CONTENT="$SALTS" perl -i -0777 -pe 's/define\(\s*'\''AUTH_KEY'\''.*?define\(\s*'\''NONCE_SALT'\''.*?\);/$ENV{SALTS_CONTENT}/s' "$WP_CONFIG_FILE"
    else
        echo "Cảnh báo: Không thể tải các khóa bảo mật từ WordPress.org. Giữ nguyên các khóa mặc định."
    fi
fi

# Thiết lập quyền sở hữu và phân quyền cho web server (www-data)
sudo chown -R www-data:www-data /var/www/html/"$wp_folder"
sudo chmod -R 755 /var/www/html/"$wp_folder"

# Hướng dẫn tiếp theo
echo ""
echo "=== Cài đặt WordPress thành công! ==="
echo "1. Thư mục mã nguồn: /var/www/html/$wp_folder"
echo "2. Thông tin database:"
echo "   - Database Name: $wp_db"
echo "   - Database User: $wp_user"
echo ""
echo "3. Bước tiếp theo, hãy chạy lệnh sau để tự động tạo cấu hình VirtualHost Nginx & SSL:"
echo "   sudo ./phpsv-config.sh --ssl -name $wp_folder -domain $domain_name"
echo "====================================="