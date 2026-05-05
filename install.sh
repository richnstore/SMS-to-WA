#!/bin/bash

# Warna output untuk informasi
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

echo -e "${BLUE}====================================================${NC}"
echo -e "${GREEN}      SMS-to-WA Gateway Installer v2.1 (Auto IP)${NC}"
echo -e "${BLUE}====================================================${NC}"

# 1. Update Sistem & Install Library Puppeteer (Paling Penting)
echo -e "${YELLOW}>>> Menginstal dependensi sistem (Chrome/Puppeteer)...${NC}"
sudo apt update && sudo apt upgrade -y
sudo apt install -y curl build-essential libnss3 libatk1.0-0 libatk-bridge2.0-0 libcups2 libdrm2 libxkbcommon0 libxcomposite1 libxdamage1 libxrandr2 libgbm1 libpango-1.0-0 libcairo2 libasound2 libxshmfence1 libglu1-mesa

# 2. Install Node.js v18 (Jika belum ada)
if ! command -v node &> /dev/null; then
    echo -e "${YELLOW}>>> Menginstal Node.js v18...${NC}"
    curl -fsSL https://deb.nodesource.com/setup_18.x | sudo -E bash -
    sudo apt install -y nodejs
fi

# 3. Setup Direktori Project
echo -e "${YELLOW}>>> Menyiapkan folder project ~/wa-gateway-v2...${NC}"
mkdir -p ~/wa-gateway-v2
cd ~/wa-gateway-v2

# 4. Buat package.json
cat <<EOF > package.json
{
  "name": "wa-gateway-v2",
  "version": "2.1.0",
  "description": "SMS to WhatsApp Gateway dengan Deteksi IP Otomatis",
  "main": "index.js",
  "dependencies": {
    "axios": "^1.6.0",
    "body-parser": "^1.20.2",
    "express": "^4.18.2",
    "qrcode-terminal": "^0.12.0",
    "whatsapp-web.js": "^1.23.0"
  }
}
EOF

# 5. Install Node Modules
echo -e "${YELLOW}>>> Menginstal library Node.js (whatsapp-web.js, express, axios)...${NC}"
npm install

# 6. Buat file index.js (Logika Utama dengan Deteksi IP)
echo -e "${YELLOW}>>> Membuat script utama index.js...${NC}"
cat <<EOF > index.js
const { Client, LocalAuth } = require('whatsapp-web.js');
const qrcode = require('qrcode-terminal');
const express = require('express');
const bodyParser = require('body-parser');
const axios = require('axios');

const app = express();
app.use(bodyParser.json());
const PORT = 3000;

const client = new Client({
    authStrategy: new LocalAuth(),
    puppeteer: {
        headless: true,
        args: [
            '--no-sandbox', 
            '--disable-setuid-sandbox', 
            '--disable-dev-shm-usage',
            '--disable-gpu'
        ],
    }
});

client.on('qr', (qr) => {
    console.log('\n' + '==================================================');
    console.log('SILAKAN SCAN QR CODE BERIKUT:');
    qrcode.generate(qr, { small: true });
    console.log('==================================================');
});

client.on('ready', () => {
    console.log('\n' + '✅ WhatsApp Client SUDAH SIAP & TERHUBUNG!');
});

client.on('message', async (msg) => {
    if (!msg.from.includes('@g.us')) {
        console.log(\`[WA MASUK] Dari: \${msg.from.replace('@c.us', '')} | Pesan: \${msg.body}\`);
    }
});

app.post('/sms-to-wa', async (req, res) => {
    const rawMessage = req.body.content;
    console.log(\`[SMS DITERIMA] Content: "\${rawMessage}"\`);

    if (rawMessage && rawMessage.includes('KirimWA#')) {
        const parts = rawMessage.split('#');
        if (parts.length >= 3) {
            let num = parts[1].trim();
            const txt = parts[2].trim();
            
            if (num.startsWith('0')) num = '62' + num.slice(1);
            const chatId = num + "@c.us";

            try {
                await client.sendMessage(chatId, txt);
                console.log(\`🚀 Sukses kirim WA ke \${num}\`);
                res.status(200).send('Success');
            } catch (err) {
                console.error('❌ Gagal Kirim:', err.message);
                res.status(500).send('Error');
            }
        }
    } else {
        res.status(200).send('Ignored');
    }
});

app.listen(PORT, async () => {
    console.log(\`🚀 Server aktif di port \${PORT}\`);
    try {
        const response = await axios.get('https://api.ipify.org?format=json');
        const publicIp = response.data.ip;
        console.log(\`🔗 WEBHOOK URL ANDA: http://\${publicIp}:\${PORT}/sms-to-wa\`);
        console.log('💡 Copy URL di atas ke kolom Webhook Server di SmsForwarder (Android)');
    } catch (err) {
        console.log(\`🔗 WEBHOOK URL: http://[CEK_IP_VPS_ANDA]:\${PORT}/sms-to-wa\`);
    }
});

client.initialize();
EOF

# 7. Setup PM2 agar berjalan selamanya
echo -e "${YELLOW}>>> Menginstal PM2 dan menjalankan service...${NC}"
sudo npm install pm2 -g
pm2 delete wa-gateway-v2 2>/dev/null
pm2 start index.js --name "wa-gateway-v2"
pm2 save

# 8. Buka Firewall
sudo ufw allow 3000/tcp

echo -e "${GREEN}====================================================${NC}"
echo -e "${GREEN}        INSTALASI BERHASIL DISIAPKAN!             ${NC}"
echo -e "${YELLOW} TUNGGU SEBENTAR SAMPAI QR CODE MUNCUL DI BAWAH...  ${NC}"
echo -e "${GREEN}====================================================${NC}"

# Tampilkan log untuk scanning
pm2 logs wa-gateway-v2 --lines 50
