import os
import torch
import torch.nn as nn
import torch.optim as optim
from torch.utils.data import Dataset, DataLoader
import torchvision.transforms as transforms
from PIL import Image
import numpy as np

# =====================================================================
# 1. PARAMETER MODEL & DATASET
# =====================================================================
CHARACTERS = "abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789-.,/() "
CHAR_TO_NUM = {char: i + 1 for i, char in enumerate(CHARACTERS)}
NUM_TO_CHAR = {i + 1: char for i, char in enumerate(CHARACTERS)}
BLANK_LABEL = 0  # CTC Blank Label
NUM_CLASSES = len(CHARACTERS) + 1  # Characters + 1 Blank

IMAGE_WIDTH = 256
IMAGE_HEIGHT = 64
BATCH_SIZE = 32
EPOCHS = 300
LEARNING_RATE = 0.001
DEVICE = torch.device("cuda" if torch.cuda.is_available() else "cpu")

# =====================================================================
# 2. DEFINISI DATASET PYTORCH (Untuk Dataset Kaggle)
# =====================================================================
class PrescriptionDataset(Dataset):
    """
    Dataset untuk membaca gambar tulisan tangan resep dokter dari Kaggle.
    Dataset ini mengasumsikan folder gambar dan file label CSV berisi:
    image_path, text_label
    """
    def __init__(self, img_dir, label_csv_path=None, transform=None):
        self.img_dir = img_dir
        self.transform = transform
        self.samples = []
        
        if label_csv_path and os.path.exists(label_csv_path):
            # Membaca pasangan (Nama file gambar, label teks obat)
            with open(label_csv_path, 'r', encoding='utf-8') as f:
                lines = f.readlines()[1:] # Lewati header
                for line in lines:
                    parts = line.strip().split(',')
                    if len(parts) >= 2:
                        img_name = parts[0]
                        label = parts[1]
                        self.samples.append((os.path.join(img_dir, img_name), label))
        else:
            # Fallback/Dummy jika file CSV tidak ditemukan (membaca dummy data untuk pengetesan script)
            print("[INFO] CSV Label tidak ditemukan. Menggunakan dummy dataset generator.")
            for filename in os.listdir(img_dir)[:100]:
                if filename.lower().endswith(('.png', '.jpg', '.jpeg')):
                    # Ambil nama file tanpa ekstensi sebagai label
                    label = os.path.splitext(filename)[0]
                    self.samples.append((os.path.join(img_dir, filename), label))

    def __len__(self):
        return len(self.samples)

    def __getitem__(self, idx):
        img_path, label = self.samples[idx]
        image = Image.open(img_path).convert('L') # Convert ke Grayscale
        
        if self.transform:
            image = self.transform(image)
            
        # Encode label teks menjadi array angka (token)
        encoded_label = [CHAR_TO_NUM[char] for char in label if char in CHAR_TO_NUM]
        label_len = len(encoded_label)
        
        return image, torch.tensor(encoded_label, dtype=torch.long), torch.tensor(label_len, dtype=torch.long)

# Custom Collate Function untuk padding label tensor dengan ukuran berbeda dalam satu batch
def collate_fn(batch):
    images, labels, label_lens = zip(*batch)
    images = torch.stack(images, 0)
    label_lens = torch.stack(label_lens, 0)
    
    # Pad label dengan 0 (blank) agar ukurannya seragam di dalam batch tensor
    max_len = max([len(l) for l in labels])
    padded_labels = torch.zeros(len(labels), max_len, dtype=torch.long)
    for i, l in enumerate(labels):
        padded_labels[i, :len(l)] = l
        
    return images, padded_labels, label_lens

# =====================================================================
# 3. STRUKTUR JARINGAN CRNN (CNN + BiLSTM + CTC Loss)
# =====================================================================
class CRNN(nn.Module):
    def __init__(self, num_classes):
        super(CRNN, self).__init__()
        
        # 1. Feature Extractor (Convolutional Neural Network)
        self.cnn = nn.Sequential(
            nn.Conv2d(1, 64, kernel_size=3, padding=1),
            nn.ReLU(True),
            nn.MaxPool2d(2, 2), # Output: 64 x 32 x 128 (H x W)
            
            nn.Conv2d(64, 128, kernel_size=3, padding=1),
            nn.ReLU(True),
            nn.MaxPool2d(2, 2), # Output: 128 x 16 x 64
            
            nn.Conv2d(128, 256, kernel_size=3, padding=1),
            nn.BatchNorm2d(256),
            nn.ReLU(True),
            nn.Conv2d(256, 256, kernel_size=3, padding=1),
            nn.ReLU(True),
            nn.MaxPool2d((2, 1), (2, 1)), # Output: 256 x 8 x 64 (Pool vertikal saja)
            
            nn.Conv2d(256, 512, kernel_size=3, padding=1),
            nn.BatchNorm2d(512),
            nn.ReLU(True),
            nn.Conv2d(512, 512, kernel_size=3, padding=1),
            nn.ReLU(True),
            nn.MaxPool2d((2, 1), (2, 1)), # Output: 512 x 4 x 64
            
            nn.Conv2d(512, 512, kernel_size=2, stride=1),
            nn.BatchNorm2d(512),
            nn.ReLU(True) # Output: 512 x 3 x 63
        )
        
        # 2. Sequence Labeling (Recurrent Neural Network - BiLSTM)
        self.rnn = nn.Sequential(
            BidirectionalLSTM(512 * 3, 256, 256),
            BidirectionalLSTM(256, 256, num_classes)
        )

    def forward(self, x):
        # x shape: [Batch, 1, Height (64), Width (256)]
        features = self.cnn(x) # Output shape: [Batch, Channels (512), Height (3), Width (W_new)]
        
        # Reshape untuk input LSTM
        batch, channels, h, w = features.size()
        features = features.view(batch, channels * h, w) # Shape: [Batch, Channels*Height, Sequence_Length]
        features = features.permute(2, 0, 1) # Shape: [Sequence_Length, Batch, Input_Size]
        
        # RNN output
        output = self.rnn(features) # Shape: [Sequence_Length, Batch, Num_Classes]
        return output

class BidirectionalLSTM(nn.Module):
    def __init__(self, input_size, hidden_size, output_size):
        super(BidirectionalLSTM, self).__init__()
        self.lstm = nn.LSTM(input_size, hidden_size, bidirectional=True)
        self.linear = nn.Linear(hidden_size * 2, output_size)

    def forward(self, x):
        recurrent, _ = self.lstm(x)
        t, b, h = recurrent.size()
        t_rec = recurrent.view(t * b, h)
        output = self.linear(t_rec)  # Shape: [T * B, Output_Size]
        output = output.view(t, b, -1)
        return output

# =====================================================================
# 4. TRAINING LOOP
# =====================================================================
def train(img_dir, csv_path, output_model_path):
    print(f"[START] Memulai training CRNN OCR di device: {DEVICE}")
    
    transform = transforms.Compose([
        transforms.Resize((IMAGE_HEIGHT, IMAGE_WIDTH)),
        transforms.ToTensor(),
        transforms.Normalize((0.5,), (0.5,))
    ])
    
    dataset = PrescriptionDataset(img_dir, csv_path, transform=transform)
    if len(dataset) == 0:
        print("[WARNING] Dataset kosong! Harap periksa folder data resep Anda.")
        return
        
    dataloader = DataLoader(dataset, batch_size=BATCH_SIZE, shuffle=True, collate_fn=collate_fn)
    
    model = CRNN(NUM_CLASSES).to(DEVICE)
    criterion = nn.CTCLoss(blank=BLANK_LABEL, zero_infinity=True)
    optimizer = optim.Adam(model.parameters(), lr=LEARNING_RATE)
    
    for epoch in range(1, EPOCHS + 1):
        model.train()
        epoch_loss = 0
        
        for batch_idx, (images, targets, target_lengths) in enumerate(dataloader):
            images = images.to(DEVICE)
            targets = targets.to(DEVICE)
            
            optimizer.zero_grad()
            
            # Forward pass
            outputs = model(images) # Shape: [Sequence_Length, Batch, Num_Classes]
            
            # Ukuran sequence panjang input (W_new dari CNN)
            input_lengths = torch.full(size=(images.size(0),), fill_value=outputs.size(0), dtype=torch.long).to(DEVICE)
            
            # Hitung CTC Loss
            # CTC Loss membutuhkan format target 1D datar (flat)
            flat_targets = torch.cat([targets[i, :target_lengths[i]] for i in range(targets.size(0))])
            
            loss = criterion(outputs, flat_targets, input_lengths, target_lengths)
            loss.backward()
            
            optimizer.step()
            epoch_loss += loss.item()
            
        print(f"Epoch [{epoch}/{EPOCHS}] - Average Loss: {epoch_loss / len(dataloader):.4f}")
        
    print("[SUCCESS] Training selesai!")
    
    # =====================================================================
    # 5. EXPORT KE FORMAT ONNX (Untuk Inferensi Offline di Node.js)
    # =====================================================================
    print(f"[EXPORT] Mengekspor model hasil latih ke format ONNX: {output_model_path}")
    model.eval()
    
    # Dummy input berupa gambar grayscale kosong berukuran 1x64x256
    dummy_input = torch.randn(1, 1, IMAGE_HEIGHT, IMAGE_WIDTH).to(DEVICE)
    
    torch.onnx.export(
        model,
        dummy_input,
        output_model_path,
        export_params=True,
        opset_version=12,
        do_constant_folding=True,
        input_names=['input_image'],
        output_names=['output_logits'],
        dynamic_axes={
            'input_image': {0: 'batch_size'},
            'output_logits': {1: 'batch_size'}
        }
    )
    print("[INFO] Model ONNX berhasil disimpan! Anda dapat menaruh file ini di backend NestJS.")

if __name__ == "__main__":
    # Path dataset Kaggle tulisan tangan resep dokter asli (dengan folder img terdalam)
    real_data_dir = "D:\\!semester6\\!a\\ocr_training\\kaggle_data\\doctor-handwriting-recognition-dataset\\img\\img"
    real_csv_path = "D:\\!semester6\\!a\\ocr_training\\kaggle_data\\doctor-handwriting-recognition-dataset\\doctor_handwriting_labels.csv"
    output_onnx_path = "D:\\!semester6\\!a\\ocr_training\\ocr_prescription_model.onnx"
    
    # Jalankan training & ekspor ke ONNX
    train(
        img_dir=real_data_dir,
        csv_path=real_csv_path,
        output_model_path=output_onnx_path
    )
