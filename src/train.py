import mlflow
import mlflow.sklearn
import pandas as pd
import yaml
import json
import joblib
import os
import pathlib
from sklearn.ensemble import RandomForestClassifier, GradientBoostingClassifier
from sklearn.linear_model import LogisticRegression
from sklearn.metrics import accuracy_score, f1_score, classification_report, confusion_matrix

EVAL_THRESHOLD = 0.70

tracking_uri = os.getenv("MLFLOW_TRACKING_URI", "sqlite:///mlflow.db")
mlflow.set_tracking_uri(tracking_uri)
try:
    if "sqlite" in tracking_uri:
        os.makedirs("mlartifacts", exist_ok=True)
        art_uri = pathlib.Path("mlartifacts").resolve().as_uri()
        exp = mlflow.get_experiment_by_name("wine-quality")
        if exp is None:
            try:
                mlflow.create_experiment("wine-quality", artifact_location=art_uri)
            except Exception:
                pass
    mlflow.set_experiment("wine-quality")
except Exception as e:
    print(f"[MLflow Warning] Could not set experiment: {e}")


def train(
    params: dict,
    data_path: str = "data/train_phase1.csv",
    eval_path: str = "data/eval.csv",
) -> float:
    """
    Huan luyen mo hinh va ghi nhan ket qua vao MLflow (Ho tro da thuat toan - Bonus 2).
    """

    # TODO 1: Doc du lieu huan luyen va danh gia
    df_train = pd.read_csv(data_path)
    df_eval  = pd.read_csv(eval_path)

    # TODO 2: Tach dac trung (X) va nhan (y)
    X_train = df_train.drop(columns=["target"])
    y_train = df_train["target"]
    X_eval  = df_eval.drop(columns=["target"])
    y_eval  = df_eval["target"]

    # BONUS 5: Canh bao lech lac du lieu (Class Distribution & Data Drift Check)
    class_counts = y_train.value_counts()
    class_dist = y_train.value_counts(normalize=True).to_dict()
    print("--- [Bonus 5] Phan phoi nhan tap huan luyen ---")
    for cls, pct in class_dist.items():
        print(f"  Lop {cls}: {class_counts[cls]} mau ({pct:.2%})")
        if pct < 0.10:
            print(f"  [WARNING] Lop {cls} chiem duoi 10% ({pct:.2%}) - Canh bao mat can bang du lieu!")

    with mlflow.start_run():

        # TODO 3: Ghi nhan cac sieu tham so
        mlflow.log_params(params)

        # BONUS 2: Khoi tao mo hinh theo model_type
        model_type = params.get("model_type", "random_forest")
        model_params = {k: v for k, v in params.items() if k != "model_type"}

        if model_type == "gradient_boosting":
            gb_params = {
                k: v for k, v in model_params.items()
                if k in ["n_estimators", "max_depth", "learning_rate", "min_samples_split"]
            }
            model = GradientBoostingClassifier(random_state=42, **gb_params)
        elif model_type == "logistic_regression":
            lr_params = {
                k: v for k, v in model_params.items()
                if k in ["max_iter", "C", "solver"]
            }
            model = LogisticRegression(random_state=42, **lr_params)
        else:
            rf_params = {
                k: v for k, v in model_params.items()
                if k in ["n_estimators", "max_depth", "min_samples_split", "min_samples_leaf", "criterion"]
            }
            model = RandomForestClassifier(random_state=42, **rf_params)

        model.fit(X_train, y_train)

        # TODO 5: Du doan tren tap danh gia va tinh chi so
        preds = model.predict(X_eval)
        acc   = accuracy_score(y_eval, preds)
        f1    = f1_score(y_eval, preds, average="weighted")

        # TODO 6: Ghi nhan chi so vao MLflow
        mlflow.log_metric("accuracy", acc)
        mlflow.log_metric("f1_score", f1)
        mlflow.sklearn.log_model(model, "model")

        # BONUS 3: Tao bao cao hieu suat tu dong (Confusion Matrix & Classification Report)
        cm = confusion_matrix(y_eval, preds)
        target_names = ["Thap (0)", "Trung binh (1)", "Cao (2)"]
        unique_labels = sorted(list(set(y_eval) | set(preds)))
        label_names = [target_names[i] if i < len(target_names) else f"Class {i}" for i in unique_labels]
        clf_report = classification_report(y_eval, preds, labels=unique_labels, target_names=label_names, zero_division=0)

        report_content = f"""==================================================
           MLOPS MODEL EVALUATION REPORT (BONUS 3)
==================================================
Algorithm: {model_type}
Accuracy:  {acc:.4f}
F1-Score:  {f1:.4f} (weighted)

--- CONFUSION MATRIX ---
{cm}

--- CLASSIFICATION REPORT ---
{clf_report}
==================================================
"""
        print(report_content)

        os.makedirs("outputs", exist_ok=True)
        with open("outputs/report.txt", "w", encoding="utf-8") as f:
            f.write(report_content)

        # TODO 8: Luu metrics ra file outputs/metrics.json (kem Class Distribution - Bonus 5)
        metrics_data = {
            "accuracy": acc,
            "f1_score": f1,
            "model_type": model_type,
            "class_distribution": {str(k): round(float(v), 4) for k, v in class_dist.items()}
        }
        with open("outputs/metrics.json", "w") as f:
            json.dump(metrics_data, f, indent=2)

        # TODO 9: Luu mo hinh ra file models/model.pkl
        os.makedirs("models", exist_ok=True)
        joblib.dump(model, "models/model.pkl")

    return acc


if __name__ == "__main__":
    with open("params.yaml") as f:
        params = yaml.safe_load(f)
    train(params)

