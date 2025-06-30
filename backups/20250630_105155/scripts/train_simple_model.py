# scripts/train_simple_model.py
import seaborn as sns
import matplotlib.pyplot as plt
import joblib
from sklearn.preprocessing import RobustScaler
from sklearn.metrics import classification_report, confusion_matrix
from sklearn.model_selection import train_test_split
from sklearn.ensemble import IsolationForest
import numpy as np
import pandas as pd
import sys
import os
sys.path.insert(0, os.path.dirname(os.path.dirname(os.path.abspath(__file__))))


def load_latest_dataset():
    """Load the most recent synthetic dataset"""
    synthetic_dir = "data/synthetic"

    # Find the most recent dataset files
    import glob
    dataset_files = glob.glob(f"{synthetic_dir}/banking_ddos_dataset_*.csv")
    label_files = glob.glob(f"{synthetic_dir}/banking_ddos_labels_*.npy")

    if not dataset_files or not label_files:
        raise FileNotFoundError(
            "No synthetic datasets found. Please run generate_synthetic_data.py first.")

    # Get the most recent files (by timestamp in filename)
    latest_dataset = sorted(dataset_files)[-1]
    latest_labels = sorted(label_files)[-1]

    print(f"📂 Loading dataset: {latest_dataset}")
    print(f"📂 Loading labels: {latest_labels}")

    data = pd.read_csv(latest_dataset)
    labels = np.load(latest_labels)

    return data, labels


def prepare_features(data):
    """Prepare features for ML training"""

    # Convert timestamp to datetime
    data['timestamp'] = pd.to_datetime(data['timestamp'])

    # Select numeric features only (exclude timestamp and boolean columns initially)
    numeric_features = data.select_dtypes(include=[np.number]).columns.tolist()

    # Remove timestamp-related columns and boolean flags for now
    exclude_cols = ['timestamp', 'is_business_hours',
                    'is_weekend', 'is_month_end']
    feature_cols = [col for col in numeric_features if col not in exclude_cols]

    print(f"🔧 Selected {len(feature_cols)} features for training")

    # Get the feature matrix
    X = data[feature_cols].copy()

    # Advanced data cleaning for banking data
    print("🧹 Cleaning data...")

    # 1. Handle infinite values (replace with NaN first)
    inf_mask = np.isinf(X)
    inf_count = inf_mask.sum().sum()
    print(f"   Found {inf_count} infinite values - replacing with NaN")
    X = X.replace([np.inf, -np.inf], np.nan)

    # 2. Handle missing values intelligently
    missing_count = X.isnull().sum().sum()
    print(f"   Found {missing_count} missing values")

    # For derived features (ratios, z-scores), use 0 instead of median
    ratio_cols = [
        col for col in X.columns if '_ratio' in col or '_score' in col]
    change_cols = [col for col in X.columns if '_change_' in col]
    zscore_cols = [col for col in X.columns if '_zscore_' in col]

    # Fill derived features with 0 (neutral values)
    for col in ratio_cols + change_cols + zscore_cols:
        if col in X.columns:
            X[col] = X[col].fillna(0)

    # Fill other features with median
    remaining_cols = [
        col for col in X.columns if col not in ratio_cols + change_cols + zscore_cols]
    for col in remaining_cols:
        X[col] = X[col].fillna(X[col].median())

    # 3. Remove any columns with all NaN or constant values
    constant_cols = []
    for col in X.columns:
        if X[col].nunique() <= 1:
            constant_cols.append(col)

    if constant_cols:
        print(
            f"   Removing {len(constant_cols)} constant columns: {constant_cols}")
        X = X.drop(columns=constant_cols)
        feature_cols = [
            col for col in feature_cols if col not in constant_cols]

    # 4. Final verification
    final_missing = X.isnull().sum().sum()
    final_inf = np.isinf(X).sum().sum()

    print(f"✅ Data cleaning complete:")
    print(f"   Final missing values: {final_missing}")
    print(f"   Final infinite values: {final_inf}")
    print(f"   Final feature matrix shape: {X.shape}")

    return X, feature_cols


def train_isolation_forest(X, y):
    """Train Isolation Forest model for anomaly detection"""

    print("\n🤖 Training Isolation Forest Model...")
    print("=" * 40)

    # Scale features
    scaler = RobustScaler()
    X_scaled = scaler.fit_transform(X)

    # Split data
    X_train, X_test, y_train, y_test = train_test_split(
        X_scaled, y, test_size=0.2, random_state=42, stratify=y
    )

    print(f"Training set: {X_train.shape[0]} samples")
    print(f"Test set: {X_test.shape[0]} samples")
    print(f"Attack ratio in training: {y_train.sum()/len(y_train)*100:.2f}%")
    print(f"Attack ratio in test: {y_test.sum()/len(y_test)*100:.2f}%")

    # Train Isolation Forest
    # Set contamination based on actual attack rate in training data
    contamination_rate = max(0.001, y_train.sum() /
                             len(y_train))  # At least 0.1%

    model = IsolationForest(
        contamination=contamination_rate,
        n_estimators=100,
        random_state=42,
        n_jobs=-1
    )

    print(f"\n🎯 Training with contamination rate: {contamination_rate:.4f}")

    # Fit on training data
    model.fit(X_train)

    # Make predictions (Isolation Forest returns -1 for anomalies, 1 for normal)
    train_pred = model.predict(X_train)
    test_pred = model.predict(X_test)

    # Convert predictions to 0/1 format (0=normal, 1=anomaly)
    train_pred_binary = (train_pred == -1).astype(int)
    test_pred_binary = (test_pred == -1).astype(int)

    # Evaluate model
    print(f"\n📊 Model Evaluation:")
    print("=" * 25)

    print("Training Set Performance:")
    print(classification_report(y_train, train_pred_binary,
          target_names=['Normal', 'Attack']))

    print("\nTest Set Performance:")
    print(classification_report(y_test, test_pred_binary,
          target_names=['Normal', 'Attack']))

    # Confusion Matrix
    cm = confusion_matrix(y_test, test_pred_binary)

    plt.figure(figsize=(10, 6))

    # Plot confusion matrix
    plt.subplot(1, 2, 1)
    sns.heatmap(cm, annot=True, fmt='d', cmap='Blues',
                xticklabels=['Normal', 'Attack'],
                yticklabels=['Normal', 'Attack'])
    plt.title('Confusion Matrix')
    plt.ylabel('True Label')
    plt.xlabel('Predicted Label')

    # Plot anomaly scores distribution
    plt.subplot(1, 2, 2)
    normal_scores = model.decision_function(X_test[y_test == 0])
    attack_scores = model.decision_function(X_test[y_test == 1])

    plt.hist(normal_scores, bins=50, alpha=0.7, label='Normal', color='blue')
    plt.hist(attack_scores, bins=50, alpha=0.7, label='Attack', color='red')
    plt.xlabel('Anomaly Score')
    plt.ylabel('Frequency')
    plt.title('Anomaly Score Distribution')
    plt.legend()

    plt.tight_layout()

    # Create models directory if it doesn't exist
    os.makedirs('data/models', exist_ok=True)
    plt.savefig('data/models/model_evaluation.png',
                dpi=300, bbox_inches='tight')
    plt.show()

    # Calculate key metrics
    tn, fp, fn, tp = cm.ravel()
    precision = tp / (tp + fp) if (tp + fp) > 0 else 0
    recall = tp / (tp + fn) if (tp + fn) > 0 else 0
    f1 = 2 * precision * recall / \
        (precision + recall) if (precision + recall) > 0 else 0

    print(f"\n🎯 Key Performance Metrics:")
    print("=" * 30)
    print(
        f"Precision: {precision:.3f} (What % of predicted attacks were real?)")
    print(f"Recall:    {recall:.3f} (What % of real attacks did we catch?)")
    print(f"F1-Score:  {f1:.3f} (Overall performance balance)")
    print(
        f"False Positive Rate: {fp/(fp+tn)*100:.2f}% (Normal traffic flagged as attacks)")
    print(f"False Negative Rate: {fn/(fn+tp)*100:.2f}% (Attacks missed)")

    return model, scaler, {
        'precision': precision,
        'recall': recall,
        'f1_score': f1,
        'false_positive_rate': fp/(fp+tn),
        'false_negative_rate': fn/(fn+tp)
    }


def save_model(model, scaler, feature_cols, metrics):
    """Save the trained model and metadata"""

    model_dir = "data/models"
    os.makedirs(model_dir, exist_ok=True)

    # Save model and scaler
    joblib.dump(model, f"{model_dir}/isolation_forest_model.pkl")
    joblib.dump(scaler, f"{model_dir}/feature_scaler.pkl")

    # Save feature columns and metrics
    metadata = {
        'model_type': 'IsolationForest',
        'feature_columns': feature_cols,
        'num_features': len(feature_cols),
        'performance_metrics': metrics,
        'trained_at': pd.Timestamp.now().isoformat()
    }

    import json
    with open(f"{model_dir}/model_metadata.json", 'w') as f:
        json.dump(metadata, f, indent=2)

    print(f"\n💾 Model Saved Successfully!")
    print(f"📁 Model files saved to: {model_dir}/")
    print("   - isolation_forest_model.pkl")
    print("   - feature_scaler.pkl")
    print("   - model_metadata.json")
    print("   - model_evaluation.png")


def main():
    """Main training function"""

    print("🤖 Banking DDoS Detection - ML Model Training")
    print("=" * 50)

    try:
        # Load data
        print("📂 Loading synthetic dataset...")
        data, labels = load_latest_dataset()

        print(f"✅ Data loaded successfully!")
        print(f"   Total samples: {len(data):,}")
        print(
            f"   Attack samples: {labels.sum():,} ({labels.sum()/len(labels)*100:.2f}%)")

        # Prepare features
        print("\n🔧 Preparing features...")
        X, feature_cols = prepare_features(data)

        # Train model
        model, scaler, metrics = train_isolation_forest(X, labels)

        # Save model
        save_model(model, scaler, feature_cols, metrics)

        print(f"\n🎉 Training Complete!")
        print("🔄 Next Steps:")
        print("1. Review model performance metrics above")
        print("2. Test the model with new data")
        print("3. Integrate with Prometheus for real-time detection")
        print("4. Set up automated retraining pipeline")

    except Exception as e:
        print(f"❌ Error during training: {e}")
        import traceback
        traceback.print_exc()


if __name__ == "__main__":
    main()
