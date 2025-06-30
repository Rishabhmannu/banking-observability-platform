# scripts/generate_synthetic_data.py
import sys
import os

# Add the project root to Python path BEFORE importing custom modules
project_root = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
sys.path.insert(0, project_root)

# Now import the custom modules
from src.data_generation.master_dataset_generator import MasterDatasetGenerator


def main():
    """Main function to generate synthetic datasets"""

    print("🏦 Banking DDoS Detection - Synthetic Data Generation")
    print("=" * 55)

    # Initialize master generator
    generator = MasterDatasetGenerator(output_dir="data/synthetic")

    # Generate training dataset
    print("\n📊 Generating Training Dataset...")
    train_data, train_labels = generator.generate_training_dataset(
        start_date="2024-01-01",
        num_days=45,  # 45 days of training data
        attack_probability=0.12,  # 12% chance of attack per day
        save_dataset=True
    )

    # Generate validation dataset
    print("\n🔍 Generating Validation Dataset...")
    val_data, val_labels = generator.generate_validation_dataset(
        start_date="2024-02-15",
        num_days=14,  # 14 days of validation data
        attack_probability=0.25,  # 25% chance of attack per day
        save_dataset=True
    )

    # Generate test dataset (clean, separate timeline)
    print("\n🧪 Generating Test Dataset...")
    test_data, test_labels = generator.generate_training_dataset(
        start_date="2024-03-01",
        num_days=10,  # 10 days of test data
        attack_probability=0.20,  # 20% chance of attack per day
        save_dataset=True
    )

    print("\n✅ Synthetic Data Generation Complete!")
    print("\nDataset Summary:")
    print(f"Training:   {len(train_data):,} samples, {int(train_labels.sum()):,} attacks ({train_labels.sum()/len(train_labels)*100:.1f}%)")
    print(
        f"Validation: {len(val_data):,} samples, {int(val_labels.sum()):,} attacks ({val_labels.sum()/len(val_labels)*100:.1f}%)")
    print(f"Test:       {len(test_data):,} samples, {int(test_labels.sum()):,} attacks ({test_labels.sum()/len(test_labels)*100:.1f}%)")

    # Preview the data
    print("\n📋 Sample Data Preview:")
    print(train_data.head())

    print("\n🎯 Next Steps:")
    print("1. Review the generated data in data/synthetic/")
    print("2. Run EDA notebooks to validate data quality")
    print("3. Use this data to train your ML models")
    print("4. Test model integration with Prometheus metrics")


if __name__ == "__main__":
    main()
