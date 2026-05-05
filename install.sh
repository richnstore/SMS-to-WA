#!/bin/bash

# Warna output
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m'

echo -e "${YELLOW}>>> Memulai Instalasi SMS-to-WA Gateway Dua Arah...${NC}"

# 1. Update & Dependencies
echo -e "${GREEN}>>> Mengupdate sistem dan instalasi library browser...${NC}"
sudo apt update && sudo apt upgrade -y
sudo apt install -y curl build-essential libnss3 libatk-bridge2.0-0 libx11-xcb1 libxcb-dri3-0 libxcomposite1 libxcursor1 libxdamage1 libxfixes3 libxi6 libxrandr2 libxrender1 libxtst6 libcups2 libdbus-1-3 libexpat1 libfontconfig1 libgbm1 libgcc1 libglib2.0-0 libgtk-3-0 libpango-1.0-0 libpangocairo-1.0-0 libstdc++6 libx11-6 libxshmfence1

# 2. Node.js
if ! command -v node &> /dev/null; then
    curl -fsSL https://deb.nodesource.com/setup_18.x | sudo -E bash -
    sudo apt install -y nodejs
fi

# 3. Setup Project
mkdir -p ~/wa-gateway-v2
cd ~/wa-gateway-v2

cat <<EOF > package.json
{
  "name": "wa-gateway-v2",
  "version": "2.0.0",
  "dependencies": {
    "body-parser": "^1.20.2",
    "express": "^4.18.2",
    "qrcode-terminal": "^0.12.0",
    "whatsapp-web.js": "^1.23.0"
  }
}
EOF

npm install

# 4. Script Utama (index.js)
cat <<EOF > index.js
const { Client, LocalAuth } = require('whatsapp-web.js');
const qrcode = require('qrcode-terminal');
const express = require('express');
const bodyParser = require('body-parser');

const app = express();
app.use(bodyParser.json());

const client = new Client({
    authStrategy: new LocalAuth(),
    puppeteer: {
        headless: true,
        args: ['--no-sandbox', '--disable-setuid-sandbox']
    }
});

// EVENT: Menampilkan QR Code
client.on('qr', (qr) => {
    console.log('SCAN QR CODE DI BAWAH INI:');
    qrcode.generate(qr, { small: true });
});

// EVENT: Client Siap
client.on('ready', () => {
    console.log('WhatsApp Client READY!');
});

// EVENT: Menerima Pesan WA (Untuk diteruskan ke Log/HP Jadul)
client.on('message', async (msg) => {
    if (!msg.from.includes('@g.us')) { // Hanya chat pribadi
        const sender = msg.from.replace('@c.us', '');
        console.log(\`[WA MASUK] Dari \${sender}: \${msg.body}\`);
        // Logika ini akan muncul di 'pm2 logs'. 
        // Untuk kirim balik ke SMS, gunakan fitur 'Notification Forwarder' di HP Android.
    }
});

// ENDPOINT: SMS -> WA (HP Jadul kirim ke Orang Lain)
app.post('/sms-to-wa', async (req, res) => {
    const rawMessage = req.body.content;
    if (rawMessage && rawMessage.includes('KirimWA#')) {
        const parts = rawMessage.split('#');
        if (parts.length >= 3) {
            let targetNumber = parts[1].trim();
            const messageText = parts[2].trim();
            if (targetNumber.startsWith('0')) targetNumber = '62' + targetNumber.slice(1);
            
            try {
                await client.sendMessage(targetNumber + "@c.us", messageText);
                console.log('Berhasil kirim WA ke:', targetNumber);
                res.status(200).send('OK');
            } catch (err) {
                res.status(500).send('Gagal');
            }
        }
    } else {
        res.status(400).send('Format Salah');
    }
});

app.listen(3000, () => console.log('Server Receiver Port 3000'));
client.initialize();
EOF

# 5. PM2 Setup
sudo npm install pm2 -g
pm2 delete wa-gateway-v2 2>/dev/null
pm2 start index.js --name "wa-gateway-v2"
sudo ufw allow 3000/tcp

echo -e "${GREEN}>>> INSTALASI SELESAI. Silakan scan QR Code di bawah ini.${NC}"
pm2 logs wa-gateway-v2 --lines 20 --no-append
