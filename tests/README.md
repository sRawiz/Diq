# Aim Assist verification

## ESP รุ่นปรับปรุง

แก้ไข `Main.lua` และ `ESPSystem.lua` ให้ขึ้น remote ต้นทางพร้อมกันก่อนใช้ loader
เพราะ Main โหลดโมดูลจาก GitHub ไม่ได้อ่านไฟล์ที่แก้ในเครื่องโดยตรง

- หน้า Visual แยก Show Teammates, Show Enemies และ Show Unknown / Neutral
  โดยค่าเริ่มต้นแสดงทุกกลุ่ม และ ESP master ยังปิดอยู่
- โหมด Relation ใช้ฟ้า/แดง/ทองตามฝ่าย เลือกสีของแต่ละฝ่ายได้จากชุดสีในเมนู
  โหมด Team ใช้สีทีมของเกม (ถ้าไม่มีทีม/เป็นกลาง ใช้สีตามฝ่าย)
  โหมด Uniform ใช้สีเดียวจาก SetColor ตาม API เดิม
- เปิด Show Names & Distance เพื่อแสดงชื่อพร้อมป้ายฝ่าย เปิด/ปิดป้ายได้แยกกัน
  ระยะวัดจากกล้องเป็น studs; Range = 0 หมายถึงไม่จำกัด
- ระบบมาตรฐานเปรียบเทียบ Team object และตรวจ Neutral ของทั้งเราและเป้าหมาย
  ถ้าฝั่งใดเป็นกลางหรือไม่มีทีม จะเป็น Unknown ไม่เหมารวมว่าเป็นศัตรู
- Team Attribute เป็นตัวเลือกสำหรับเกมที่เก็บฝ่ายไว้ใน Attribute บน Player:
  กรอกชื่อ Attribute ที่มีจริง เช่น Faction จึงจะใช้ค่านั้นแทน Team/Neutral
  รองรับ string ที่ไม่ว่างหรือ number (รวม 0); ค่าเท่ากันเป็นเพื่อนร่วมทีม
  ค่าต่างกันเป็นศัตรู ค่าที่ขาดหาย/boolean/NaN เป็น Unknown
  ไม่ค้นหา Attribute บน Character หรือระบบฝ่ายเฉพาะเกมให้อัตโนมัติ
  ล้างช่องแล้วออกจากช่องเพื่อกลับไปใช้ทีม Roblox
- ปิด ESP จะซ่อนภาพทันทีและหยุด render connection; ปิดหน้าต่างจะ cleanup
  Highlight ยังใช้งานได้เมื่อ Drawing API ไม่พร้อม พร้อมข้อความเตือนครั้งเดียว
  การรองรับ Drawing และ CoreGui ต้องตรวจด้วย executor ที่ใช้งานจริง

รันทดสอบแบบจำลองด้วย Luau ทางการ:

```powershell
python tests/run_esp.py --luau-dir C:/path/to/luau
```

ชุดนี้ compile ไฟล์ Lua ใน repository และทดสอบ production ESP ด้วย engine mocks
ครอบคลุมฝ่าย/Neutral/Attribute, สี, การกรอง, ระยะ, กล้อง, ตาย/เกิดใหม่,
ไม่มี Head, HP สูงสุดเป็นศูนย์, ผู้เล่นเข้าออก, Drawing ขาดหาย และ cleanup
ไม่ได้ยืนยันภาพจริงหรือสิทธิ์ของ executor

ตรวจในเกมเพิ่มเติม: เปิด ESP และองค์ประกอบทุกชนิด สลับทีมทั้งเราและเป้าหมาย
ลอง Unknown/Neutral และตัวกรองแต่ละกลุ่ม สลับโหมดสี/ระยะ จากนั้นตายเกิดใหม่
ปิดหน้าต่างและรัน loader ซ้ำ ต้องไม่มีภาพหรือ handler ของรอบเก่าค้าง
สำหรับเกม FFA ที่ไม่มี Team ผู้เล่นจะอยู่ใน Unknown; เปิดกลุ่มนี้เพื่อให้แสดง

## Aim Assist

Run with official Windows Luau binaries (`luau.exe` and `luau-compile.exe`):

```powershell
python tests/run_aimbot.py --luau-dir C:/path/to/luau
```

The runner compiles all repository Lua files and runs the production aim module
against mocked Roblox services. This verifies control flow and selection logic;
it does not prove compatibility with an actual executor or custom game camera.
The mock camera models direction interpolation, not full Roblox CFrame rotation.

## Simple interface

Upload Main.lua, AimbotSystem.lua and DiqUILib.lua together. The Aim Assist tab has:

- Aim Assist [Q]: the toggle and Q shortcut control the same enabled state.
- Aim At: Head or Body, with R6/R15 torso and root/PrimaryPart fallbacks.
- FOV Radius: 20-400 pixels, default 150 (not camera field of view in degrees).
- Show FOV: enabled by default; displayed while assist is active.

Main applies the simple preset automatically. It uses Camera output, visible
living opponents, native Roblox team filtering and a 3000-stud distance cap.
Balanced ranking weighs normalized crosshair distance 70% and physical distance
30%. A substantially better candidate must remain better across scans before
an automatic switch. Invalid targets are replaced immediately.

Camera correction is strongest near the reticle and softer at the FOV edge.
It begins from the game's current camera orientation each frame, allowing
manual aim changes instead of resuming a previously forced direction. This is
a camera assist, not a recreation of Apex controller slowdown/rotational assist.
It does not inspect weapons, infer projectile speed, or predict ballistics.

The old advanced module methods remain available to existing callers, but their
controls and the T shortcut are not part of the simple interface. Legacy camera
mode still preserves its previous lock behavior unless ApplyAssistPreset is used.

## Live acceptance checks

1. Start from a fresh loader run in your own map with another player.
2. Press Q while the panel toggle is off. The toggle should become on and assist
   should start without a second activation step. Press Q again to stop.
3. Toggle on through UI. Check Head and Body on R6/R15 characters; move the reticle
   near and away from targets. Assistance should be gentler near the FOV edge.
4. Put a wall between camera and target. That target must not remain eligible.
5. Check team changes, deaths, respawns and player departures. Q must not activate
   while typing or while the Roblox menu is open. Leaving the application window
   or local respawn disables assist and updates the UI toggle; press Q to resume.
6. Hide/show the panel with its window shortcut, then close it and rerun the
   loader. Closing must stop aim updates and remove the FOV overlay.

## Coverage and limits

Tests cover Q/UI state synchronization, processed input, focus and respawn;
R6/R15 and missing/invalid part fallbacks; current-camera soft response and
FOV-edge strength; walls, teams, death, range and offscreen filtering;
frame-rate response factors; deterministic ranking, target-switch debounce;
legacy manual cycling and rebinding; executor mouse failures; and repeated
initialization/destruction. Interactive widget callbacks require a live check.

There is no guaranteed all-map adapter. Maps with custom non-Humanoid rigs,
custom team systems, camera updates after this controller, or weapon reticles
away from viewport center may need map-specific integration. NPCs are not
included. The simple preset does not require Drawing or mousemoverel.
