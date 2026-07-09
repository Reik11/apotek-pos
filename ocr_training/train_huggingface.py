import os
import sys
import torch
import torch.nn as nn
import torch.optim as optim
from torch.utils.data import Dataset, DataLoader
import torchvision.transforms as transforms
from PIL import Image
import numpy as np

# Menangani output encoding UTF-8 di Windows
sys.stdout.reconfigure(encoding='utf-8')

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
BATCH_SIZE = 16
EPOCHS = 5  # Diatur sedikit untuk demo agar cepat selesai. Anda bisa mengubah ke 30-50 epoch.
LEARNING_RATE = 0.001
DEVICE = torch.device("cuda" if torch.cuda.is_available() else "cpu")

# =====================================================================
# 2. DEFINISI DATASET WRAPPER UNTUK HUGGINGFACE
# =====================================================================
class HuggingFaceOcrDataset(Dataset):
    """
    Dataset wrapper untuk memetakan data dari pustaka datasets HuggingFace ke PyTorch.
    """
    def __init__(self, hf_dataset, transform=None):
        self.dataset = hf_dataset
        self.transform = transform
        
        # Ambil sampel item pertama untuk mendeteksi keys secara riil
        first_item = hf_dataset[0]
        keys = list(first_item.keys())
        print(f"DEBUG: Dataset item keys are: {keys}")
        
        # Cari nama kolom label secara dinamis
        self.label_col = None
        for col in ['label', 'text', 'word', 'label_text']:
            if col in keys:
                self.label_col = col
                break
        if not self.label_col:
            for col in keys:
                if col != 'image':
                    self.label_col = col
                    break
                    
        print(f"📌 Menggunakan kolom label: '{self.label_col}'")
        
        # Cek jika kolom tersebut adalah ClassLabel (kategori integer ID)
        self.classes = None
        if self.label_col and self.label_col in hf_dataset.features:
            from datasets import ClassLabel
            feature = hf_dataset.features[self.label_col]
            if isinstance(feature, ClassLabel):
                self.classes = feature

    def __len__(self):
        return len(self.dataset)

    def __getitem__(self, idx):
        item = self.dataset[idx]
        image = item['image'].convert('L')
        
        # Baca label secara dinamis
        label = ""
        if self.label_col:
            label_val = item[self.label_col]
            if self.classes is not None:
                label = self.classes.int2str(label_val)
            else:
                label = str(label_val)
        else:
            # Jika tidak ada kolom label, ambil kata obat dari nama file gambar asli
            import re
            filename = getattr(item['image'], 'filename', '')
            if filename:
                basename = os.path.splitext(os.path.basename(filename))[0]
                # Hilangkan angka-angka indeks (misal: 'Amoxicillin_1' -> 'Amoxicillin')
                label = re.sub(r'[\d_-]+', ' ', basename).strip()
            else:
                label = "prescription"
                
        # Cetak sesekali saja untuk meyakinkan label terisi dengan nama obat
        if idx == 0 or idx == 10 or idx == 20:
            print(f"DEBUG: Dataset item index {idx} mapped to label word: '{label}'")
        
        if self.transform:
            image = self.transform(image)
            
        # Encode label teks menjadi array angka (token)
        encoded_label = [CHAR_TO_NUM[char] for char in label if char in CHAR_TO_NUM]
        
        # Fallback jika tidak ada karakter yang cocok dalam kamus
        if not encoded_label:
            encoded_label = [CHAR_TO_NUM[' ']]
            
        label_len = len(encoded_label)
        
        return image, torch.tensor(encoded_label, dtype=torch.long), torch.tensor(label_len, dtype=torch.long)

def collate_fn(batch):
    images, labels, label_lens = zip(*batch)
    images = torch.stack(images, 0)
    label_lens = torch.stack(label_lens, 0)
    
    # Pad label dengan 0 (blank) agar ukurannya seragam di dalam batch
    max_len = max([len(l) for l in labels])
    padded_labels = torch.zeros(len(labels), max_len, dtype=torch.long)
    for i, l in enumerate(labels):
        padded_labels[i, :len(l)] = l
        
    return images, padded_labels, label_lens

# =====================================================================
# 3. STRUKTUR JARINGAN CRNN (CNN + BiLSTM + CTC Loss)
# =====================================================================
class BidirectionalLSTM(nn.Module):
    def __init__(self, input_size, hidden_size, output_size):
        super(BidirectionalLSTM, self).__init__()
        self.lstm = nn.LSTM(input_size, hidden_size, bidirectional=True)
        self.linear = nn.Linear(hidden_size * 2, output_size)

    def forward(self, x):
        recurrent, _ = self.lstm(x)
        t, b, h = recurrent.size()
        t_rec = recurrent.view(t * b, h)
        output = self.linear(t_rec)
        output = output.view(t, b, -1)
        return output

class CRNN(nn.Module):
    def __init__(self, num_classes):
        super(CRNN, self).__init__()
        
        self.cnn = nn.Sequential(
            nn.Conv2d(1, 64, kernel_size=3, padding=1),
            nn.ReLU(True),
            nn.MaxPool2d(2, 2),
            
            nn.Conv2d(64, 128, kernel_size=3, padding=1),
            nn.ReLU(True),
            nn.MaxPool2d(2, 2),
            
            nn.Conv2d(128, 256, kernel_size=3, padding=1),
            nn.BatchNorm2d(256),
            nn.ReLU(True),
            nn.Conv2d(256, 256, kernel_size=3, padding=1),
            nn.ReLU(True),
            nn.MaxPool2d((2, 1), (2, 1)),
            
            nn.Conv2d(256, 512, kernel_size=3, padding=1),
            nn.BatchNorm2d(512),
            nn.ReLU(True),
            nn.Conv2d(512, 512, kernel_size=3, padding=1),
            nn.ReLU(True),
            nn.MaxPool2d((2, 1), (2, 1)),
            
            nn.Conv2d(512, 512, kernel_size=2, stride=1),
            nn.BatchNorm2d(512),
            nn.ReLU(True)
        )
        
        self.rnn = nn.Sequential(
            BidirectionalLSTM(512 * 3, 256, 256),
            BidirectionalLSTM(256, 256, num_classes)
        )

    def forward(self, x):
        features = self.cnn(x)
        batch, channels, h, w = features.size()
        features = features.view(batch, channels * h, w)
        features = features.permute(2, 0, 1)
        output = self.rnn(features)
        return output

# =====================================================================
# 4. TRAINING ENGINE
# =====================================================================
def main():
    try:
        # Load library datasets dari HuggingFace
        from datasets import load_dataset
    except ImportError:
        print("ERROR: Library 'datasets' belum terinstal.")
        print("Silakan instal dengan menjalankan perintah:")
        print("pip install datasets transformers torch torchvision pillow sentencepiece protobuf")
        sys.exit(1)

    print("🌐 Downloading/Loading dataset dari HuggingFace: 'avi-kai/Medical_Prescription_Handwritten_Words'...")
    try:
        # Unduh & muat dataset secara otomatis lewat API internet
        hf_dataset_dict = load_dataset("avi-kai/Medical_Prescription_Handwritten_Words")
        
        # Ambil pembagian data training (jika tidak ada train/test split, gunakan split 'train')
        train_data = hf_dataset_dict['train']
        print(f"✅ Dataset berhasil dimuat! Total data latih: {len(train_data)} gambar kata.")
    except Exception as e:
        print(f"❌ Gagal mengunduh dataset dari link HuggingFace: {str(e)}")
        sys.exit(1)

    # Transformasi gambar untuk model CRNN
    transform = transforms.Compose([
        transforms.Resize((IMAGE_HEIGHT, IMAGE_WIDTH)),
        transforms.ToTensor(),
        transforms.Normalize((0.5,), (0.5,))
    ])

    # Wrap ke PyTorch Dataset & DataLoader
    dataset = HuggingFaceOcrDataset(train_data, transform=transform)
    dataloader = DataLoader(dataset, batch_size=BATCH_SIZE, shuffle=True, collate_fn=collate_fn)

    print(f"🤖 Memulai training CRNN OCR menggunakan device: {DEVICE}")
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
            outputs = model(images)
            
            input_lengths = torch.full(size=(images.size(0),), fill_value=outputs.size(0), dtype=torch.long).to(DEVICE)
            
            # Format target 1D datar (flat)
            flat_targets = torch.cat([targets[i, :target_lengths[i]] for i in range(targets.size(0))])
            
            loss = criterion(outputs, flat_targets, input_lengths, target_lengths)
            loss.backward()
            optimizer.step()
            
            epoch_loss += loss.item()
            
        print(f"Epoch [{epoch}/{EPOCHS}] - Average Loss: {epoch_loss / len(dataloader):.4f}")

    print("🎉 Training selesai!")

    # Export hasil ke format ONNX
    output_onnx_path = "D:\\!semester6\\!a\\ocr_training\\ocr_prescription_model.onnx"
    print(f"📦 Mengekspor model hasil latih ke: {output_onnx_path}")
    
    model.eval()
    dummy_input = torch.randn(1, 1, IMAGE_HEIGHT, IMAGE_WIDTH).to(DEVICE)
    
    torch.onnx.export(
        model,
        dummy_input,
        output_onnx_path,
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
    print("✅ Model ONNX berhasil disimpan! Model ini sudah siap menggantikan backend dummy lama.")

if __name__ == "__main__":
    main()
