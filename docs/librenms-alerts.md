# **🛠️ LibreNMS Riasztás & Telegram Javítási Útmutató**

Ez a dokumentum összefoglalja a **LibreNMS** riasztási rendszerének optimalizálását, a **Blade template** hibák javítását és a **Telegram spam** megszüntetését.

## **📋 1\. Miket javítottunk?**

* **Sablon hiba:** Megszüntettük a string | array típusú hibaüzenetet a Telegram értesítésekben.  
* **Spam szűrés:** Beállítottunk egy egészséges egyensúlyt a riasztások gyakorisága között.  
* **Adatbázis javítás:** Frissítettük a rejtett JSON beállításokat az alert\_rules táblában.

## **🔧 2\. Rendszer Karbantartás (SSH)**

Ha a webes felület nem frissül, vagy furcsán viselkedik, futtasd ezeket a /opt/librenms mappában:

### **📂 Jogosultságok helyreállítása**

chown \-R librenms:librenms /opt/librenms  
setfacl \-R \-m g::rwx /opt/librenms/rrd /opt/librenms/logs /opt/librenms/bootstrap/cache /opt/librenms/storage

### **🧹 Gyorsítótár ürítése (Cache Clear)**

sudo \-u librenms php artisan cache:clear  
sudo \-u librenms php artisan view:clear  
sudo \-u librenms php artisan config:clear

### **🔍 Diagnosztika**

sudo \-u librenms ./validate.php

## **📊 3\. Ellenőrző Parancsok (Status Check)**

Használd ezeket a parancsokat, hogy lásd a rendszer aktuális állapotát:

### **⏱️ Időzítések ellenőrzése (Delay & Interval)**

sudo mysql \-u librenms \-p$(cat /opt/librenms/.env | grep DB\_PASSWORD | cut \-d'=' \-f2) librenms \-e "SELECT name, JSON\_EXTRACT(extra, '$.delay') AS delay\_sec, JSON\_EXTRACT(extra, '$.interval') AS interval\_sec FROM alert\_rules;"

### **✉️ Sablon tartalmának ellenőrzése**

sudo mysql \-u librenms \-p$(cat /opt/librenms/.env | grep DB\_PASSWORD | cut \-d'=' \-f2) librenms \-e "SELECT name, template FROM alert\_templates WHERE name='Proxmox Homelab Alert';"

## **🚀 4\. Javító és Optimalizáló Parancsok**

### **🛑 Tömeges Spam szűrés beállítása**

Beállítja az **5 perc késleltetést** és az **1 óra ismétlést** minden szabályra:

sudo mysql \-u librenms \-p$(cat /opt/librenms/.env | grep DB\_PASSWORD | cut \-d'=' \-f2) librenms \-e "UPDATE alert\_rules SET extra \= JSON\_SET(extra, '$.delay', 300, '$.interval', 3600, '$.count', \-1);"

### **💎 Sablon hiba végleges javítása (Blade fix)**

sudo mysql \-u librenms \-p$(cat /opt/librenms/.env | grep DB\_PASSWORD | cut \-d'=' \-f2) librenms \-e "UPDATE alert\_templates SET template='@if (\\$alert-\>state \== 1\) 🔴 RIASZTÁS @else ✅ HELYREÁLLT @endif\\n\\n🧬 Host: {{ \\$alert-\>sysName }}\\n🌐 IP: {{ \\$alert-\>hostname }}\\n🔥 Szabály: {{ \\$alert-\>name }}\\n⚠️ Szint: {{ \\$alert-\>severity }}\\n🕒 Idő: {{ \\$alert-\>timestamp }}\\n\\n@if (\\$alert-\>faults)\\n📋 Hiba részletei:\\n@foreach (\\$alert-\>faults as \\$key \=\> \\$value)\\n\#{{ \\$key }}: {{ \\$value\[\\"string\\"\] }}\\n@endforeach\\n@endif' WHERE name='Proxmox Homelab Alert';"

## **💡 Fontos tudnivalók**

1. **Mértékegységek:** Az adatbázisban minden idő **másodpercben** van (300 mp \= 5 perc, 3600 mp \= 1 óra).  
2. **Frissítés:** SQL módosítás után a böngészőben mindig nyomj **CTRL \+ F5**\-öt.  
3. **Biztonság:** A fenti parancsok automatikusan kiolvassák az adatbázis jelszavadat a .env fájlból, nem kell kézzel beírnod.

**Készült:** 2026\. március 18\.

**Állapot:** Optimalizált / Stabil
