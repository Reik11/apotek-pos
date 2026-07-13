from datasets import load_dataset

print("Loading dataset...")
try:
    dataset = load_dataset("avi-kai/Medical_Prescription_Handwritten_Words")
    print("Splits:", list(dataset.keys()))
    train_data = dataset['train']
    print("Column names:", train_data.column_names)
    print("Features:", train_data.features)
    print("First item keys:", list(train_data[0].keys()))
    print("First item sample:", {k: str(type(v)) for k, v in train_data[0].items()})
except Exception as e:
    print("Error:", e)
