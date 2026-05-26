# LEMP Stack Toolkit

Bộ công cụ Script Bash tối ưu, tự động hóa toàn diện quy trình cài đặt, cấu hình và quản trị môi trường **LEMP** (Linux, Nginx, MySQL, PHP-FPM) trên hệ điều hành **Ubuntu Server**. 

Được thiết kế chuyên biệt để đáp ứng các tiêu chuẩn vận hành thực tế (Production-ready) cho các dự án **Laravel** (bao gồm cả Laravel Octane/Swoole), **WordPress**, và các ứng dụng PHP hiện đại khác.

---

## 🚀 Điểm Nổi Bật & Tối Ưu Hóa Production

Không chỉ đơn thuần là cài đặt các gói phần mềm, bộ công cụ tích hợp sẵn các cấu hình tối ưu hiệu năng cao nhất:

*   **Kiến trúc LEMP thuần (Pure LEMP):** Sử dụng Nginx làm Web Server kết hợp PHP-FPM qua Unix Socket. Loại bỏ hoàn toàn Apache mặc định để giảm hao phí tài nguyên tối đa (Apache chỉ còn là tùy chọn bổ sung).
*   **Tối ưu hóa PHP OPcache:** Cấu hình sẵn dung lượng cache lớn (256MB), lưu trữ lên đến 10,000 files, tắt kiểm tra thay đổi file liên tục (`revalidate_freq=0`) trên production để tối ưu tốc độ phản hồi tối đa.
*   **PHP-FPM Pool Tuning:** Chuyển cấu hình quản lý tiến trình sang chế độ `dynamic`, cho phép tăng tốc lên đến 50 worker khi chịu tải cao và tự động restart worker sau mỗi 500 request (`max_requests = 500`) nhằm triệt tiêu hoàn toàn hiện tượng rò rỉ bộ nhớ (memory leaks).
*   **Bảo mật & Tối ưu Nginx:**
    *   Tự động bật **Gzip Compression** (mức 6) cho toàn bộ các định dạng file tĩnh phổ biến.
    *   Cấu hình sẵn các **Security Headers** chuẩn (`X-Frame-Options`, `X-Content-Type-Options`, `X-XSS-Protection`, `Referrer-Policy`).
    *   Cấu hình **FastCGI Buffers** lớn (128k/256k) tránh lỗi phản hồi bị cắt khúc hoặc gián đoạn đối với Laravel/WordPress.
    *   Cấu hình Cache tệp tĩnh tối ưu (`expires 30d`, `open_file_cache`).
    *   Giới hạn dung lượng tải lên mặc định tăng lên **100MB** (`client_max_body_size`).
*   **Hỗ trợ Laravel Octane:** Tích hợp sẵn proxy ngược (Reverse Proxy) hỗ trợ Swoole, truyền tải kết nối WebSocket và tự động sinh cấu hình PM2 quản lý tiến trình tự động.
*   **Triển khai Git an toàn (Zero-Downtime-like Sync):** Quy trình triển khai code sử dụng cơ chế clone nguồn về thư mục nguồn riêng `/var/www/sources` rồi đồng bộ bằng `rsync` có bộ lọc loại trừ (`.git`, `.env`, log,...) sang thư mục chạy `/var/www/html` giúp tránh làm gián đoạn ứng dụng đang chạy.

---

## 🛠️ Yêu Cầu Hệ Thống

*   **Hệ điều hành:** Ubuntu Server (Đã kiểm thử tốt trên các phiên bản 20.04 LTS, 22.04 LTS, 24.04 LTS).
*   **Kiến trúc CPU:** Hỗ trợ cả x86_64 và ARM64 (AWS Graviton, Oracle ARM).
*   **Quyền hạn:** Cần chạy dưới quyền `root` hoặc thông qua lệnh `sudo`.
*   **Kết nối Internet:** Yêu cầu đường truyền mạng ổn định để tải các gói phần mềm từ PPA Ondrej PHP và các repo chính thức.

> [!WARNING]  
> Các script này được thiết kế và kiểm thử chỉ dành riêng cho hệ điều hành Ubuntu Linux. **KHÔNG** chạy trực tiếp các script này trên hệ điều hành macOS hoặc Windows nội bộ.

---

## 📂 Chi Tiết Bộ Script

Bộ toolkit bao gồm 7 script chuyên biệt, mỗi script đảm nhận một vai trò cụ thể trong vòng đời phát triển:

### 1. [lemp.sh](./lemp.sh) — Khởi Tạo Toàn Diện Hệ Thống
Script này sẽ thiết lập nền tảng server ban đầu từ hệ điều hành sạch.
*   **Cài đặt:** Nginx, MySQL Server, PHP 8.3, Composer (bản mới nhất), Node.js v20 LTS, PM2 và Certbot.
*   **Các thành phần PHP Extension cài sẵn:** Hỗ trợ tối đa Laravel/WordPress/Octane (`fpm`, `cli`, `mysql`, `curl`, `gd`, `mbstring`, `xml`, `zip`, `bcmath`, `sqlite3`, `intl`, `opcache`, `tokenizer`, `ctype`, `fileinfo`, `imagick`, `exif`, `redis`, `swoole`).
*   **Cách sử dụng:**
    ```bash
    chmod +x lemp.sh
    sudo ./lemp.sh
    ```

### 2. [lemp-migrate.sh](./lemp-migrate.sh) — Nâng Cấp & Di Trú Hệ Thống An Toàn
Dành cho máy chủ cũ đang sử dụng file `lemp.sh` bản cũ trong thư mục `vendor` (chạy song song Nginx làm proxy ngược sang Apache2 cổng 8080).
*   **Tính năng nổi bật:**
    *   **Nâng cấp an toàn:** Cài đặt PHP 8.3 cùng các extension mới nhất, tối ưu cấu hình OPcache và PHP-FPM pool tương tự bản mới mà **không** gỡ bỏ hay làm ảnh hưởng tới các dịch vụ quan trọng (Nginx, Apache2, MySQL) và dữ liệu các website cũ.
    *   **Tối ưu hóa toàn cục Nginx:** Thêm cấu hình tối ưu hiệu năng và bảo mật (`conf.d/optimization.conf`), tự động xử lý/vô hiệu hóa directive `gzip on;` trùng lặp trong file `/etc/nginx/nginx.conf` gốc.
    *   **Cập nhật môi trường:** Cài đặt Node.js v20 LTS, PM2 toàn cục, loại bỏ Certbot cài qua snap để chuyển sang bản Certbot apt tối ưu và ổn định hơn.
*   **Cách sử dụng:**
    ```bash
    chmod +x lemp-migrate.sh
    sudo ./lemp-migrate.sh
    ```
*   **Hướng dẫn chuyển đổi cấu hình Nginx site cũ sang Pure Nginx (PHP-FPM) để tối ưu hiệu năng:**
    1. Mở file cấu hình Nginx của site cũ cần chuyển đổi (ví dụ: `/etc/nginx/sites-available/ten-site`).
    2. Tìm đoạn cấu hình proxy cũ chuyển tiếp yêu cầu sang Apache2:
        ```nginx
        location / {
            proxy_pass http://127.0.0.1:8080;
            ...
        }
        ```
    3. Xóa đoạn proxy trên và thay bằng cấu hình PHP-FPM mới (chạy trực tiếp trên socket của PHP 8.3):
        ```nginx
        location / {
            try_files $uri $uri/ /index.php?$query_string;
        }

        location ~ \.php$ {
            fastcgi_read_timeout 3000;
            fastcgi_pass unix:/run/php/php8.3-fpm.sock;
            include snippets/fastcgi-php.conf;
            fastcgi_param SCRIPT_FILENAME $document_root$fastcgi_script_name;
            include fastcgi_params;
        }
        ```
    4. Kiểm tra cú pháp cấu hình và tải lại Nginx:
        ```bash
        sudo nginx -t && sudo systemctl reload nginx
        ```

### 3. [phpsv-config.sh](./phpsv-config.sh) — Cấu Hình VirtualHost (Tên Miền & SSL)
Tự động tạo cấu hình Nginx/Apache cho tên miền dự án của bạn, hỗ trợ SSL Let's Encrypt tự động.
*   **Cú pháp:**
    ```bash
    sudo ./phpsv-config.sh [options] -name <tên_dự_án> -domain <tên_miền> [-root <đường_dẫn>] [-port <cổng_octane>]
    ```
*   **Các tham số bổ sung:**
    *   `--nginx`: Tạo cấu hình cho Nginx (Mặc định).
    *   `--apache`: Chỉ tạo cấu hình cho Apache2 (Chạy trên cổng 8080 nếu cần sử dụng song song).
    *   `--ssl`: Tự động đăng ký và cấu hình SSL HTTPS miễn phí qua Certbot.
    *   `--laravel`: Tự động thêm hậu tố `/public` vào thư mục Root nếu chưa có.
    *   `--octane`: Bật chế độ cấu hình ngược (Reverse Proxy) cho Laravel Octane (Swoole). Nginx sẽ tự động chuyển hướng các request động về cổng chỉ định và trực tiếp phục vụ các tệp tĩnh. Tự sinh file `ecosystem.config.js` cho PM2.
    *   `-name` / `-n`: Tên định danh cấu hình (dùng đặt tên file cấu hình, tên folder dự án).
    *   `-domain` / `-d`: Tên miền chính (có thể khai báo nhiều cờ `-d` để thiết lập Server Alias / Subdomain).
    *   `-root` / `-r`: Đường dẫn tuyệt đối của thư mục chứa code (Mặc định: `/var/www/html/<tên_dự_án>`).
    *   `-port` / `-p`: Cổng chạy Laravel Octane (Mặc định: 8000).
*   **Ví dụ sử dụng:**
    *   *Dự án PHP/WordPress thông thường với SSL:*
        ```bash
        sudo ./phpsv-config.sh --ssl -name myblog -domain myblog.com -domain www.myblog.com
        ```
    *   *Dự án Laravel truyền thống (chạy PHP-FPM):*
        ```bash
        sudo ./phpsv-config.sh --laravel --ssl -name myapp -domain myapp.com
        ```
    *   *Dự án Laravel Octane (Swoole) chạy trên cổng 8010:*
        ```bash
        sudo ./phpsv-config.sh --octane --ssl -name myoctane -domain octaneapp.com -port 8010
        ```

### 4. [php-setup.sh](./php-setup.sh) — Quản Lý & Nâng Cấp Phiên Bản PHP
Cho phép cài đặt thêm phiên bản PHP mới (ví dụ 8.1, 8.2, 8.3, 8.4) chạy song song và cập nhật cấu hình hệ thống một cách an toàn.
*   **Đo độ tin cậy cao:** Không xóa các phiên bản PHP cũ, tránh nguy cơ làm sập các trang web hiện có đang chạy phiên bản cũ hơn.
*   **Tự động cập nhật:** Tự động sửa lại đường dẫn PHP-FPM Socket trong các cấu hình Nginx hiện có và cập nhật liên kết PHP CLI mặc định qua `update-alternatives`.
*   **Cách sử dụng:**
    ```bash
    sudo ./php-setup.sh [phiên_bản]
    # Ví dụ: cài đặt/chuyển đổi sang PHP 8.4
    sudo ./php-setup.sh 8.4
    ```

### 5. [php-fix.sh](./php-fix.sh) — Khắc Phục Lỗi & Tái Cấu Hình Nhanh
Công cụ chuẩn đoán và sửa các lỗi phát sinh thường gặp.
*   **Các tác vụ sửa lỗi:** 
    *   Kiểm tra và ghi đè các cấu hình `php.ini` bị sai lệch về mức tối ưu (memory_limit, upload limits, execution time).
    *   Sửa lỗi phân quyền ghi Session trong thư mục `/var/lib/php/sessions` cho user `www-data`.
    *   Kiểm tra tính hợp lệ của cú pháp cấu hình Nginx (`nginx -t`) trước khi khởi động lại để tránh làm sập Web Server.
    *   Tự động phát hiện và khởi động lại chính xác dịch vụ PHP-FPM đang hoạt động.
*   **Cách sử dụng:**
    ```bash
    sudo ./php-fix.sh
    ```

### 6. [wp.sh](./wp.sh) — Cài Đặt WordPress Nhanh
Khởi tạo mã nguồn và cơ sở dữ liệu WordPress trong vài giây.
*   **Tính năng:** 
    *   Tự động tải phiên bản WordPress mới nhất, kiểm tra lỗi tải xuống và tự động dọn dẹp file nén tạm thời `latest.tar.gz` sau khi giải nén.
    *   Tạo Database MySQL + User MySQL + Cấp quyền tương ứng một cách an toàn.
    *   Thiết lập phân quyền thư mục `www-data:www-data` chuẩn xác.
    *   Hỗ trợ chạy hoàn toàn tự động (non-interactive) bằng cách truyền các cờ database qua dòng lệnh.
*   **Cách sử dụng:**
    *   *Chế độ tương tác (hỏi khi chạy):*
        ```bash
        sudo ./wp.sh --name myblog --domain myblog.com
        ```
    *   *Chế độ tự động (truyền sẵn thông số database):*
        ```bash
        sudo ./wp.sh --name myblog --domain myblog.com --db-name wp_db --db-user wp_user --db-pass wp_password
        ```

### 7. [gcp.sh](./gcp.sh) — Tự Động Hóa Triển Khai Từ Git (Deploy Script Generator)
Hỗ trợ clone code từ Git và sinh ra script cập nhật tự động cho dự án.
*   **Cơ chế:** 
    1. Clone/Pull mã nguồn từ Git về `/var/www/sources/<tên_thư_mục>`.
    2. Sử dụng `rsync` để đồng bộ sạch sang `/var/www/html/<tên_thư_mục>`, loại trừ các tệp tin cấu hình môi trường `.env` và thư mục `.git`.
    3. Tự động sinh một deploy script tại `/var/www/shell/<tên_thư_mục>.sh` phục vụ cho việc cập nhật code sau này (tiện lợi cho việc cài đặt Webhook hoặc chạy qua cronjob).
*   **Hỗ trợ Laravel chuyên sâu:** Nếu truyền cờ `--laravel`, script sẽ thực hiện:
    *   Tạo file `.env` từ file ví dụ nếu chưa có.
    *   Chạy `composer install --no-dev --optimize-autoloader`.
    *   Tự động sinh ứng dụng `APP_KEY` nếu trống.
    *   Thiết lập phân quyền chuẩn cho thư mục `storage` và `bootstrap/cache`.
    *   *Trong Deploy script sinh ra:* Tự động chạy chuỗi lệnh tối ưu hóa Laravel (`config:cache`, `route:cache`, `view:cache`) và tự động khởi động lại Laravel Octane qua PM2 nếu phát hiện file `ecosystem.config.js`.
*   **Cách sử dụng:**
    ```bash
    sudo ./gcp.sh <Git_URL> [tên_thư_mục] [--laravel]
    # Ví dụ với Laravel:
    sudo ./gcp.sh https://github.com/example/my-laravel-project.git myapp --laravel
    ```
    *Để cập nhật code sau này, bạn chỉ cần chạy file script đã được sinh ra:*
    ```bash
    sudo /var/www/shell/myapp.sh
    ```

---

## 📋 Quy Trình Triển Khai Thực Tế Khuyên Dùng

Để dựng một hệ thống hoàn chỉnh chạy ứng dụng Laravel/WordPress trên máy chủ mới, hãy làm theo các bước sau:

### Bước 1: Khởi tạo Server
```bash
git clone <URL_repo_LEMP_Toolkit> lemp-toolkit
cd lemp-toolkit
chmod +x *.sh
sudo ./lemp.sh
```

### Bước 2: Triển khai mã nguồn từ Git
```bash
sudo ./gcp.sh https://github.com/user/laravel-app.git myapp --laravel
```

### Bước 3: Cấu hình Virtual Host & SSL
*   **Đối với Laravel truyền thống (PHP-FPM):**
    ```bash
    sudo ./phpsv-config.sh --laravel --ssl -name myapp -domain mydomain.com
    ```
*   **Đối với Laravel Octane (Swoole):**
    1. Thiết lập VirtualHost với Octane:
       ```bash
       sudo ./phpsv-config.sh --octane --ssl -name myapp -domain mydomain.com -port 8000
       ```
    2. File cấu hình PM2 `ecosystem.config.js` đã tự động sinh ra trong `/var/www/html/myapp`. Bạn hãy khởi động Octane bằng cách:
       ```bash
       cd /var/www/html/myapp
       pm2 start ecosystem.config.js
       ```

### Bước 4: Kiểm tra và vận hành
Nếu gặp bất kỳ vấn đề gì về phân quyền hoặc cấu hình PHP trong quá trình chạy, hãy sử dụng:
```bash
sudo ./php-fix.sh
```

---

## 🔒 Bản Quyền & Giấy Phép

Mã nguồn mở và phát triển tự do. Bạn có thể tùy biến cấu hình theo nhu cầu của doanh nghiệp hoặc cá nhân.
