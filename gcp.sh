#!/bin/bash

# Kiểm tra quyền root
if [ "$EUID" -ne 0 ]; then
  echo "Vui lòng chạy script này với quyền root hoặc sử dụng sudo."
  exit 1
fi

# Định nghĩa các thư mục cần thiết
TARGET_DIR_HTML="/var/www/html"
TARGET_DIR_SOURCES="/var/www/sources"
SHELL_DIR="/var/www/shell"

# Kiểm tra và khởi tạo các thư mục nếu chưa tồn tại
mkdir -p "$TARGET_DIR_SOURCES" "$SHELL_DIR"

# Kiểm tra nếu số lượng tham số ít hơn 1
if [ "$#" -lt 1 ]; then
  read -p "Enter the Git URL: " GIT_URL
  read -p "Enter the folder name (leave empty for default): " CLONE_FOLDER
  read -p "Is this a Laravel project? (yes/no): " IS_LARAVEL
  if [ "$IS_LARAVEL" == "yes" ]; then
    LARAVEL_FLAG="--laravel"
  else
    LARAVEL_FLAG=""
  fi
else
  GIT_URL="$1"
  CLONE_FOLDER="$2"
  LARAVEL_FLAG="$3"
fi

# Kiểm tra nếu tham số thứ 2 là --laravel, điều chỉnh CLONE_FOLDER và LARAVEL_FLAG
if [ "$2" == "--laravel" ]; then
  CLONE_FOLDER=""
  LARAVEL_FLAG="$2"
elif [ "$3" == "--laravel" ]; then
  LARAVEL_FLAG="$3"
fi

# Kiểm tra URL Git có hợp lệ không
if [ -z "$GIT_URL" ]; then
  echo "Invalid URL: The Git URL cannot be empty."
  exit 1
fi

# Clone repository vào thư mục /var/www/sources
echo "Cloning repository into $TARGET_DIR_SOURCES..."
cd "$TARGET_DIR_SOURCES" || exit 1

if [ -z "$CLONE_FOLDER" ]; then
  CLONE_FOLDER=$(basename "$GIT_URL" .git)
fi

if [ -d "$TARGET_DIR_SOURCES/$CLONE_FOLDER" ]; then
  echo "Thư mục $CLONE_FOLDER đã tồn tại. Cập nhật mã nguồn..."
  cd "$TARGET_DIR_SOURCES/$CLONE_FOLDER" || exit 1
  git pull
else
  git clone "$GIT_URL" "$CLONE_FOLDER"
  cd "$TARGET_DIR_SOURCES/$CLONE_FOLDER" || exit 1
fi

# Đồng bộ project từ /var/www/sources sang /var/www/html bằng rsync (tối ưu & sạch)
echo "Đồng bộ project từ $TARGET_DIR_SOURCES/$CLONE_FOLDER sang $TARGET_DIR_HTML/$CLONE_FOLDER..."
rsync -avz --delete --exclude='.git' --exclude='.env' --exclude='storage/logs/*' --exclude='storage/framework/cache/*' "$TARGET_DIR_SOURCES/$CLONE_FOLDER/" "$TARGET_DIR_HTML/$CLONE_FOLDER/"

cd "$TARGET_DIR_HTML/$CLONE_FOLDER/" || exit 1

# Tạo nội dung cho file deploy script
SHELL_SCRIPT_CONTENT=$(cat <<EOF
#!/bin/bash

echo "=== Deploy bắt đầu: $(date) ==="
cd /var/www/sources/$CLONE_FOLDER/ || exit 1

echo "Pulling latest code..."
git pull

echo "Đồng bộ code sang /var/www/html/$CLONE_FOLDER/ ..."
rsync -avz --delete --exclude='.git' --exclude='.env' --exclude='storage/logs/*' --exclude='storage/framework/cache/*' /var/www/sources/$CLONE_FOLDER/ /var/www/html/$CLONE_FOLDER/
EOF
)

# Nếu là project Laravel, thêm các bước xử lý bổ sung
if [ "$LARAVEL_FLAG" == "--laravel" ]; then
  # Kiểm tra và cài đặt Composer nếu chưa tồn tại
  if ! command -v composer &> /dev/null; then
    echo "Composer is not installed. Installing Composer..."
    EXPECTED_CHECKSUM="$(php -r 'copy("https://composer.github.io/installer.sig", "php://stdout");')"
    php -r "copy('https://getcomposer.org/installer', 'composer-setup.php');"
    ACTUAL_CHECKSUM="$(php -r 'echo hash_file("sha384", "composer-setup.php");')"
    if [ "$EXPECTED_CHECKSUM" != "$ACTUAL_CHECKSUM" ]; then
      echo 'ERROR: Invalid installer checksum' >&2
      rm composer-setup.php
      exit 1
    fi
    php composer-setup.php --install-dir=/usr/local/bin --filename=composer
    rm composer-setup.php
  else
    echo "Composer is already installed."
  fi

  cd "$TARGET_DIR_HTML/$CLONE_FOLDER/" || exit 1

  # Thiết lập file .env nếu chưa tồn tại
  echo "Checking for .env file..."
  if [ ! -f ".env" ]; then
    if [ -f ".env.example" ]; then
      cp .env.example .env
      echo "Copied .env.example to .env"
    elif [ -f ".env.development" ]; then
      cp .env.development .env
      echo "Copied .env.development to .env"
    elif [ -f ".env.production" ]; then
      cp .env.production .env
      echo "Copied .env.production to .env"
    else
      echo "No suitable .env file found"
    fi
  fi

  # Cài đặt composer dependencies
  echo "Running composer install..."
  composer install --no-dev --optimize-autoloader

  # Sinh application key nếu chưa có
  if grep -q "APP_KEY=$" .env 2>/dev/null || grep -q "APP_KEY=base64:" .env 2>/dev/null; then
    echo "APP_KEY đã tồn tại."
  else
    php artisan key:generate
    echo "Đã sinh APP_KEY mới."
  fi

  # Phân quyền các thư mục cần thiết cho www-data
  echo "Phân quyền thư mục cho www-data..."
  sudo chown -Rf www-data:www-data storage bootstrap/cache
  sudo chmod -Rf 775 storage bootstrap/cache

  # Phân quyền các thư mục tùy chỉnh nếu tồn tại
  for dir in themes public/static/contents public/static/assets resources/views/themes; do
    if [ -d "$dir" ]; then
      sudo chown -Rf www-data:www-data "$dir"
    fi
  done

  # Thêm các bước Laravel vào deploy script
  LARAVEL_STEPS=$(cat <<LARAVEL_EOF

echo "cd /var/www/html/$CLONE_FOLDER/"
cd /var/www/html/$CLONE_FOLDER/ || exit 1

echo "Running composer install..."
composer install --no-dev --optimize-autoloader

echo "Running Laravel optimizations..."
php artisan config:cache
php artisan route:cache
php artisan view:cache

echo "Phân quyền thư mục cho www-data..."
sudo chown -Rf www-data:www-data storage bootstrap/cache
sudo chmod -Rf 775 storage bootstrap/cache

# Phân quyền các thư mục tùy chỉnh nếu tồn tại
for dir in themes public/static/contents public/static/assets resources/views/themes; do
  if [ -d "\$dir" ]; then
    sudo chown -Rf www-data:www-data "\$dir"
  fi
done

# Nếu dự án chạy Laravel Octane (có PM2 ecosystem file), restart Octane
if [ -f "ecosystem.config.js" ]; then
  echo "Phát hiện Laravel Octane. Đang restart..."
  pm2 restart ecosystem.config.js 2>/dev/null || pm2 start ecosystem.config.js
  echo "Octane đã được restart thành công."
fi
LARAVEL_EOF
)
  SHELL_SCRIPT_CONTENT="${SHELL_SCRIPT_CONTENT}${LARAVEL_STEPS}"
fi

# Thêm timestamp kết thúc
SHELL_SCRIPT_CONTENT="${SHELL_SCRIPT_CONTENT}
echo \"=== Deploy hoàn tất: \$(date) ===\"
"

# Tạo file deploy script trong thư mục /var/www/shell
echo "$SHELL_SCRIPT_CONTENT" > "$SHELL_DIR/$CLONE_FOLDER.sh"
chmod +x "$SHELL_DIR/$CLONE_FOLDER.sh"

echo "Setup complete!"
echo "Deploy script created at $SHELL_DIR/$CLONE_FOLDER.sh"