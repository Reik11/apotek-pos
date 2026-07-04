import sys
import os
import re

# Menangani output encoding UTF-8 agar karakter spesial tercetak dengan benar di Windows
sys.stdout.reconfigure(encoding='utf-8')

def clean_json_output(prediction):
    """
    Membersihkan tag XML hasil prediksi Donut dan mengubahnya menjadi format resep yang ramah dibaca.
    """
    # Bersihkan tag pembuka/penutup XML/HTML
    cleaned = re.sub(r'<[^>]+>', ' ', prediction)
    # Bersihkan spasi ganda
    cleaned = re.sub(r'\s+', ' ', cleaned).strip()
    return cleaned

def parse_donut_structure(prediction):
    """
    Mengekstrak teks jika Donut mengembalikan struktur terstruktur.
    """
    # Mencoba mencocokkan tag obat seperti <s_name>Obat</s_name> dll.
    drugs = re.findall(r'<s_name>(.*?)</s_name>', prediction)
    dosages = re.findall(r'<s_dosage>(.*?)</s_dosage>', prediction)
    frequencies = re.findall(r'<s_frequency>(.*?)</s_frequency>', prediction)
    
    if drugs:
        lines = []
        for i in range(len(drugs)):
            drug = drugs[i].strip()
            dosage = dosages[i].strip() if i < len(dosages) else ""
            freq = frequencies[i].strip() if i < len(frequencies) else ""
            
            line = f"R/ {drug}"
            if dosage:
                line += f" {dosage}"
            if freq:
                line += f"\nS. {freq}"
            lines.append(line)
        return "\n".join(lines)
        
    return clean_json_output(prediction)

def main():
    if len(sys.argv) < 2:
        print("ERROR: Harap sertakan path gambar resep. Contoh: python inference.py <path_gambar>")
        sys.exit(1)
        
    image_path = sys.argv[1]
    if not os.path.exists(image_path):
        print(f"ERROR: File gambar tidak ditemukan di path: {image_path}")
        sys.exit(1)

    try:
        # Import transformer hanya saat dipanggil untuk mempercepat deteksi argumen awal
        from transformers import DonutProcessor, VisionEncoderDecoderModel
        from PIL import Image
        import torch
    except ImportError:
        print("ERROR: Library 'transformers', 'torch', atau 'pillow' belum terinstal.")
        print("Silakan instal dengan menjalankan perintah:")
        print("pip install transformers torch torchvision pillow sentencepiece protobuf")
        sys.exit(1)

    try:
        model_name = "chinmays18/medical-prescription-ocr"
        
        # Inisialisasi model dan processor
        processor = DonutProcessor.from_pretrained(model_name)
        model = VisionEncoderDecoderModel.from_pretrained(model_name)

        device = "cuda" if torch.cuda.is_available() else "cpu"
        model.to(device)

        # Muat gambar
        image = Image.open(image_path).convert("RGB")

        # Preprocessing gambar untuk Donut
        task_prompt = "<s_prescription>"
        decoder_input_ids = processor.tokenizer(task_prompt, add_special_tokens=False, return_tensors="pt").input_ids
        
        pixel_values = processor(image, return_tensors="pt").pixel_values

        # Kirim data ke device (CPU/GPU)
        pixel_values = pixel_values.to(device)
        decoder_input_ids = decoder_input_ids.to(device)

        # Jalankan inferensi
        outputs = model.generate(
            pixel_values,
            decoder_input_ids=decoder_input_ids,
            max_length=model.config.decoder.max_position_embeddings,
            pad_token_id=processor.tokenizer.pad_token_id,
            eos_token_id=processor.tokenizer.eos_token_id,
            use_cache=True,
            bad_words_ids=[[processor.tokenizer.unk_token_id]],
            return_dict_in_generate=True,
        )

        # Decode output menjadi teks
        sequence = processor.batch_decode(outputs.sequences)[0]
        sequence = sequence.replace(processor.tokenizer.eos_token, "").replace(processor.tokenizer.pad_token, "")
        sequence = re.sub(r"<.*?>", "", sequence, count=1).strip()  # Hapus prompt tugas pertama

        # Format output
        formatted_text = parse_donut_structure(sequence)
        
        # Jika hasil format kosong, fallback ke teks yang bersih
        if not formatted_text.strip():
            formatted_text = clean_json_output(sequence)
            
        print("--- START OCR RESULT ---")
        print(formatted_text)
        print("--- END OCR RESULT ---")

    except Exception as e:
        print(f"ERROR: Terjadi kegagalan saat inferensi model: {str(e)}")
        sys.exit(1)

if __name__ == "__main__":
    main()
