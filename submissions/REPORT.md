# BÁO CÁO THỰC HÀNH LAB MLOPS
## DAY 21: CI/CD CHO AI SYSTEMS – TỪ THỰC NGHIỆM ĐẾN TRIỂN KHAI LIÊN TỤC

* **Học viên:** Nguyễn Thành An
* **Mã sinh viên / ID:** 01017 - K3
* **Khóa học:** AI In Action - VinUni
* **Repository GitHub:** [Track2-Day21-K3-01017-NguyenThanhAn](https://github.com/Muscar1a/Track2-Day21-K3-01017-NguyenThanhAn)

---

### 1. Phân Tích & Lựa Chọn Siêu Tham Số (Kết Quả Bước 1)

Trong quá trình thực nghiệm cục bộ với mô hình **RandomForestClassifier** trên tập dữ liệu Wine Quality, hệ thống MLflow đã theo dõi các lần chạy với các bộ siêu tham số khác nhau:

| Run ID / Thí nghiệm | `n_estimators` | `max_depth` | `min_samples_split` | Accuracy | F1-Score (weighted) | Đánh giá |
| :--- | :---: | :---: | :---: | :---: | :---: | :--- |
| **Run 1** | 50 | 3 | 2 | 0.5580 | 0.5185 | Underfitting (cây quá nông) |
| **Run 2** | 100 | 5 | 2 | 0.5640 | 0.5534 | Mức cơ bản ban đầu |
| **Run 3 (Tối ưu)** | **200** | **10** (hoặc **20**) | **5** (hoặc **2**) | **0.6440** $\rightarrow$ **0.6840** | **0.6417** $\rightarrow$ **0.6830** | **Hiệu quả cao nhất** |

* **Lý do lựa chọn:**
  - **Độ sâu cây (`max_depth`):** Tăng từ 3 lên 10–20 giúp mô hình nắm bắt được các mối quan hệ phi tuyến phức tạp giữa 12 chỉ số hóa học của rượu vang và nhãn chất lượng (Accuracy tăng từ 55.8% lên trên 64.4%–68.4%).
  - **Số lượng cây (`n_estimators = 200`):** Giúp giảm phương sai (variance), làm ổn định kết quả dự đoán tổng hợp của toàn bộ rừng cây.

---

### 2. Đánh Giá Hiệu Suất Pipeline & Huấn Luyện Liên Tục (Bước 2 & 3)

Hệ thống CI/CD trên GitHub Actions đã tự động hóa toàn bộ quy trình kiểm thử, huấn luyện và triển khai với chốt chặn chất lượng (Eval Gate $\ge 0.60$ – $0.70$):

| Chỉ số đánh giá | Bước 2 (Phase 1: 2998 mẫu) | Bước 3 (Phase 1 + 2: 5996 mẫu) | Mức cải thiện ($\Delta$) |
| :--- | :---: | :---: | :---: |
| **Accuracy** | **0.6440** (64.4%) | **0.7540** (75.4%) | **+11.0%** 🚀 |
| **F1-Score (weighted)**| **0.6417** | **0.7534** | **+11.2%** |
| **Trạng thái Deploy** | Triển khai thành công | Triển khai tự động | Vượt xa ngưỡng Eval Gate ($\ge 0.70$) |

* **Nhận xét:** Việc bổ sung 2998 mẫu mới kết hợp với bộ siêu tham số tối ưu (`max_depth: 20`, `n_estimators: 200`) ở Bước 3 đã giúp mô hình học sâu hơn, nâng độ chính xác từ 64.4% lên **75.4%** (vượt xa ngưỡng chất lượng 0.70), chứng minh tính hiệu quả tuyệt đối của quy trình Continuous Training tự động.

---

### 3. Khó Khăn Gặp Phải & Giải Pháp Kỹ Thuật

1. **Lỗi `ModuleNotFoundError: No module named 'pkg_resources'` (MLflow 2.13):**
   - *Nguyên nhân:* Phiên bản `setuptools >= 72.0` đã loại bỏ `pkg_resources`.
   - *Giải pháp:* Ghim phiên bản `setuptools<70` trong `requirements.txt` để đảm bảo tương thích ổn định.

2. **Chính sách GCP Organization chặn tạo Service Account Key (`disableServiceAccountKeyCreation`):**
   - *Nguyên nhân:* Môi trường lab/enterprise của GCP có Organization Policy cấm tạo file key tĩnh `.json`.
   - *Giải pháp:* Tự động hóa hạ tầng bằng Terraform với chuẩn bảo mật cao cấp **Workload Identity Federation (WIF - Keyless Authentication)** cho GitHub Actions và gắn trực tiếp Service Account vào Cloud VM, không cần dùng bất kỳ file key tĩnh nào.

3. **Deploy Job bị timeout khi kiểm tra Healthcheck trên máy ảo `e2-micro`:**
   - *Nguyên nhân:* Máy ảo cấu hình tối thiểu cần khoảng 8–9 giây để tải model từ Cloud Storage và khởi động Uvicorn.
   - *Giải pháp:* Bổ sung vòng lặp retry 10 lần (cách nhau 3s) trong GitHub Actions script giúp bước kiểm tra `/health` luôn ổn định và đạt 100% tỷ lệ thành công.

4. **Xung đột cú pháp `curl` trên Windows PowerShell:**
   - *Nguyên nhân:* PowerShell hiểu nhầm chuỗi JSON trong cờ `-d` của `curl`.
   - *Giải pháp:* Chuẩn hóa lệnh kiểm tra bằng `Invoke-RestMethod` hoặc escape chuỗi `curl.exe` chuẩn xác.
