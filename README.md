# LEMP Stack Toolkit

Bộ công cụ tự động hóa cài đặt và cấu hình môi trường LEMP (Linux, Nginx, MySQL, PHP) cho máy chủ web. Các script này giúp cài đặt, cấu hình và quản lý các thành phần cần thiết cho việc triển khai ứng dụng web trên nền tảng Linux.

## Giới thiệu

LEMP Stack Toolkit bao gồm một số script bash tự động hóa việc cài đặt và cấu hình các thành phần của stack LEMP:

- **Linux**: Nền tảng hệ điều hành
- **Nginx**: Web server
- **MySQL**: Hệ quản trị cơ sở dữ liệu
- **PHP**: Ngôn ngữ lập trình phía máy chủ

## Danh sách các script

### 1. lemp.sh
Script chính để cài đặt đầy đủ stack LEMP (Linux, Nginx, MySQL, PHP), bao gồm:
- Cài đặt Apache (chạy song song với Nginx trên cổng 8080)
- Cài đặt Nginx làm reverse proxy
- Cài đặt PHP và các module cần thiết
- Cài đặt MySQL Server
- Cài đặt các công cụ phụ trợ (composer, certbot, pm2, etc.)

### 2. php-setup.sh
Script để cài đặt hoặc cập nhật phiên bản PHP trên hệ thống:
- Cài đặt phiên bản PHP mới
- Cập nhật từ phiên bản cũ lên phiên bản mới
- Cấu hình PHP tối ưu (memory_limit, upload_max_filesize, etc.)
- Cập nhật cấu hình liên quan trong Apache và Nginx

### 3. php-fix.sh
Script sửa lỗi và tái cấu hình PHP khi cần thiết:
- Sửa các lỗi phổ biến trong cấu hình PHP
- Cài đặt và cấu hình mod_rpaf cho Apache
- Khởi động lại các dịch vụ

### 4. phpsv-config.sh
Script tạo cấu hình máy chủ ảo (Virtual Host) cho dự án web:
- Tạo cấu hình cho Nginx
- Tạo cấu hình cho Apache
- Hỗ trợ cấu hình SSL với certbot
- Tùy chỉnh đặc biệt cho dự án Laravel

### 5. wp.sh
Script tự động cài đặt WordPress:
- Tải và cài đặt WordPress mới nhất
- Tạo cơ sở dữ liệu và user MySQL
- Thiết lập quyền cho thư mục WordPress

### 6. gcp.sh
Script quản lý triển khai dự án từ Git:
- Clone repository từ Git về máy chủ
- Thiết lập cấu trúc thư mục phù hợp
- Tạo script tự động pull và cập nhật code
- Hỗ trợ đặc biệt cho dự án Laravel

## Cách sử dụng

### Cài đặt LEMP stack đầy đủ:
```bash
chmod +x lemp.sh
sudo ./lemp.sh
```

### Cài đặt hoặc cập nhật PHP:
```bash
chmod +x php-setup.sh
sudo ./php-setup.sh [phiên_bản]
```
Ví dụ: `sudo ./php-setup.sh 8.3`

### Tạo cấu hình máy chủ ảo:
```bash
chmod +x phpsv-config.sh
sudo ./phpsv-config.sh --nginx --ssl -name myproject -domain example.com -root /var/www/html/myproject
```

### Cài đặt WordPress:
```bash
chmod +x wp.sh
sudo ./wp.sh --name mysite --domain example.com
```

### Triển khai dự án từ Git:
```bash
chmod +x gcp.sh
sudo ./gcp.sh https://github.com/username/repo.git [folder_name] [--laravel]
```

## Yêu cầu hệ thống

- Hệ điều hành Linux (đã thử nghiệm trên Ubuntu)
- Quyền root hoặc sudo
- Kết nối internet để tải các gói

## Các tính năng chính

- Cài đặt tự động LEMP stack đầy đủ
- Cấu hình tối ưu cho PHP, Nginx và Apache
- Hỗ trợ SSL/HTTPS thông qua certbot
- Triển khai tự động dự án từ Git
- Hỗ trợ đặc biệt cho dự án Laravel
- Quản lý phiên bản PHP
