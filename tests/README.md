# Diq verification

## หาและย้ายเซิร์ฟเวอร์

**Find Best Server (Roblox)** ให้ Roblox เลือกเซิร์ฟเวอร์โดยไม่ระบุ JobId
เหมาะเมื่อต้องการให้คำนึงถึงตำแหน่งและความหน่วงของผู้ใช้ ตาม
[สัญญาณ matchmaking ของ Roblox](https://create.roblox.com/docs/matchmaking/attributes-and-signals)
ระบบยังใช้ปัจจัยอื่น เช่น เพื่อนในเซิร์ฟเวอร์ จึงไม่รับประกันว่าได้เซิร์ฟเวอร์ใกล้ที่สุด
ping ต่ำที่สุด หรือเปลี่ยน JobId เสมอ ปุ่มนี้แสดงข้อจำกัดไว้ในหน้า Settings
ใช้ `MiscSystem.FindBestServer()` ซึ่งคืน boolean ผลการส่งคำขอ เช่นเดียวกับ Rejoin
ใช้ล็อก/timeout/TeleportInitFailed/cleanup ร่วมกับคำสั่งย้ายเซิร์ฟเดิม และไม่ต้องดาวน์โหลดรายชื่อเซิร์ฟเวอร์
ยังใช้ client `Teleport` ตาม executor runtime เดิม ไม่เรียก `TeleportAsync` ที่ต้องทำงานบน server
ไม่มีการอ่าน IP หรือส่งตำแหน่งผู้ใช้ให้บริการภายนอก

หน้า Settings > SERVER MANAGEMENT มี Find New Server สำหรับค้นหาแล้วเข้าร่วม
public server ของ PlaceId เดิมที่ยังไม่เต็มและไม่ใช่ JobId ปัจจุบัน โดยไล่ได้สูงสุด 10 หน้า
Cancel Server Search หรือปุ่ม End ยกเลิกช่วงค้นหาได้ ส่วน Rejoin Server ยังคงใช้สำหรับเข้าเซิร์ฟเดิม
(เมื่ออยู่คนเดียว Roblox จะเลือกเซิร์ฟเวอร์ให้ตามพฤติกรรม Rejoin เดิม)
การค้นหาและ Rejoin ใช้ล็อกร่วมกัน ป้องกันคำขอซ้อนกัน

`MiscSystem.ServerHop()` คืน `true` เมื่อเริ่มค้นหา หรือ `false, reason` หากเริ่มไม่ได้
`SetServerListener(callback)` รับ `(phase, message)` โดย phase เป็น Searching, Teleporting,
Failed หรือ Cancelled; Teleporting หมายถึงกำลังส่งคำขอ ไม่ใช่ยืนยันว่าเข้าเซิร์ฟเวอร์สำเร็จ
ค้นหาหมดเวลาที่ 30 วินาที และรอ teleport ได้ 45 วินาที หากล้มเหลวให้กดค้นหาใหม่
เมื่อปิดแผงจะล้าง task และ connection และไม่ให้ HTTP response เก่าเริ่ม teleport ภายหลัง
การยกเลิกไม่รับประกันว่าจะหยุด HTTP transport ที่ executor ส่งไปแล้ว
หรือยกเลิก teleport ที่ส่งให้ Roblox ไปแล้วได้

ใช้ `game:HttpGet` ของ executor เช่นเดียวกับ loader เดิม โดยตรวจ capability และรายงาน
ข้อผิดพลาด download/JSON/teleport แยกกัน ไม่ใช้ proxy, cookie หรือโหลดโค้ดเพิ่มเติม
อ้างอิง [Games API](https://create.roblox.com/docs/cloud/reference/domains/games)
และ [TeleportService](https://create.roblox.com/docs/reference/engine/classes/TeleportService)
ใช้ client teleport API ตาม runtime ของโปรเจกต์นี้

`run_infrastructure.py` รวม Misc suite: pagination, server filtering, malformed response,
HTTP failure/timeout, teleport failure/timeout, duplicate actions, cancel และ cleanup
ControlCenter suite ตรวจปุ่มค้นหา/ยกเลิก/Find Best Server จริงและปุ่ม End ด้วย engine mocks
Misc suite ตรวจ matchmaking โดยไม่กำหนด JobId/ไม่เรียก HTTP, ล็อกคำขอซ้อน,
ความล้มเหลวทั้งทันทีและภายหลัง, timeout และ cleanup
ยังไม่ได้ตรวจว่า matchmaking เลือกภูมิภาคใดหรือช่วยลด ping ในเกมจริง
ให้ทดลอง Find Best Server แล้วเทียบ ping ก่อน/หลัง และเผื่อกรณี Roblox เลือกเซิร์ฟเดิม
ยังไม่ได้ทดสอบ HTTP หรือ teleport บน Roblox/executor จริง ต้องตรวจว่า JobId หลังย้ายเปลี่ยนไป
และลองกดซ้ำ/ปิดแผงระหว่างค้นหา รวมถึงตรวจข้อความเมื่อ HTTP ถูกบล็อกหรือเซิร์ฟเวอร์เต็ม
ใช้ `python tools/build.py` เพื่อสร้าง `dist/Diq.lua` จากไฟล์ในเครื่อง
ถ้าใช้ remote loader ต้องนำ Main.lua, MiscSystem.lua และ ControlCenter.lua ขึ้นต้นทางด้วยกัน

## UI components

Workspace layout: หน้าแรก Quick Actions, sidebar ย่ออัตโนมัติและย่อด้วยปุ่มได้,
การ์ดคำสั่งเปลี่ยน 2 → 1 คอลัมน์ตามความกว้าง และปุ่มเดี่ยวขนาดตามข้อความ
Components suite ตรวจ resize, การกดการ์ดไม่แก้ขนาดที่ grid จัดไว้, navigation ในโหมดย่อ,
และ cleanup ระหว่าง callback รอทำงาน ส่วน ControlCenter suite ตรวจ profile IDs และ
การนำทางกลับแท็บเจ้าของหลังย้าย controls เข้า section
ยังต้องตรวจภาพจริงและ input บน Roblox/executor โดยเฉพาะจอเล็ก dropdown และการลากหน้าต่าง

Window suite ตรวจ Minimize/restore แบบปุ่มด้านล่าง, shortcut, การเรียกคืนด้วย SelectTab,
ขนาด/ตำแหน่งเดิมหลังลาก, สลับคำสั่งระหว่าง tween, hide/show ระหว่าง restore,
การกดซ้ำและ Destroy ระหว่าง animation โดยไม่มี task/handler ค้าง
ตรวจ layout units ระหว่าง UIScale เพื่อไม่ให้ card grid, section และ canvas ยุบตาม scale ซ้ำ
mock tween จำลองการยกเลิกและ Completed state; ไม่จำลองการวาดภาพหรือทุกเฟรมระหว่าง tween
ต้องตรวจ live ว่ามุมซ้ายบน/ล่างไม่มีพื้นหลังสี่เหลี่ยมทับขอบ และลองย่อ/คืน/กด K หลังลากหน้าต่าง

แก้ซอร์สใน `ui/` แล้วใช้ `python tools/build.py` เพื่อสร้าง `DiqUILib.lua` และ bundle
ดู [คู่มือ components](../docs/ui-components.md) สำหรับ API, ownership และการเพิ่ม controls
`python tests/test_ui_build.py` ตรวจ dependency/cycle, deterministic output และ stale artifact
`run_infrastructure.py` ตรวจ freshness, compile ทุก UI component และรัน Components suite เพิ่มจาก UI suite เดิม
Components suite ใช้ production constructors โดยไม่มี Window/Tab และตรวจ composed Slider/Hotkey,
nested sections, partial startup rollback และการปิดหน้าต่างเดิมหลังเปิดหน้าต่างใหม่

## Loading screen

`Main.lua` แสดงหน้า Loading ก่อนดาวน์โหลดโมดูล โดยใช้ GUI ที่สร้างในไฟล์เอง
แถบเปอร์เซ็นต์แสดงขั้นตอนโหลด/ตั้งค่า ไม่ใช่เปอร์เซ็นต์จำนวนไบต์หรือเวลาที่เหลือ
เมื่อสำเร็จหน้าจอจะปิดเอง หากล้มเหลวจะ rollback โมดูลและแสดงข้อความพร้อมปุ่ม Close
Cancel หยุดการเริ่มงานต่อและเก็บกวาด GUI แต่ไม่สามารถยกเลิก HTTP request ที่ executor ส่งไปแล้วได้
ผลตอบกลับที่มาภายหลังจะไม่เริ่มโมดูลหรือรบกวน session ใหม่

Loading เริ่มแสดงเมื่อ `Main.lua` เริ่มทำงานแล้วเท่านั้น ไม่ครอบคลุมการ attach executor
หรือการดาวน์โหลด `Main.lua` ด้วย loader ภายนอก หากสร้าง GUI ไม่ได้จะเตือนและโหลดต่อ
ใช้ CoreGui เมื่อมีสิทธิ์ และ fallback ไป PlayerGui; ไม่มี Drawing หรือไฟล์ภาพภายนอก

Loader suite ตรวจ startup แบบมีการ yield, success/failure, Cancel, rerun ระหว่างเริ่มงาน
และ HTTP response ที่กลับมาหลัง session ถูกแทนที่ พร้อมตรวจ cleanup ของ handlers
ยังต้องตรวจภาพจริง ขนาดหน้าจอ ปุ่ม Cancel/Close และ fallback สิทธิ์บน executor จริง

## Control Center

คู่มือฟีเจอร์ใหม่อยู่ใน [control-center.md](../docs/control-center.md)
`run_infrastructure.py` รวม ControlCenter suite: ทดสอบ production UI buttons,
profile validation/rollback, per-place storage, shortcut conflicts/capture/Hold,
performance budgets, Quick Actions และ frame sample cleanup
JSON codec, filesystem และ clipboard เป็น mock; ยังต้องทดสอบสิทธิ์และ UI layout บน executor จริง
เมื่อใช้ Main รุ่นนี้ Q และปุ่มอื่นถูกจัดการผ่านแท็บ Keybinds และ dispatcher กลาง
ชื่อ Aim Assist ใน UI ไม่มีตัวอักษร [Q] ตายตัวแล้ว เพราะผู้ใช้เปลี่ยนปุ่มได้

## Infrastructure รุ่นใหม่

ดูสัญญา runtime, build และ lifecycle ใน [architecture.md](../docs/architecture.md)

```powershell
python tests/run_infrastructure.py --luau-dir C:/path/to/luau
python tools/build.py
```

ชุดทดสอบ compile source และ bundle แล้วรัน production infrastructure, feature modules,
UI และ Main ด้วย engine mocks ตรวจ startup failure, การโหลด SHA เดียว,
การเปิดซ้ำ, property ownership, respawn, input cleanup และ no-op updates
ไฟล์ `dist/Diq.lua` เป็นผล build จาก local source และไม่โหลดโมดูลจาก GitHub ขณะรัน
หากใช้ Main แบบ remote ต้องอัปโหลด Infrastructure.lua และไฟล์ที่แก้ทั้งหมดใน commit เดียวกัน
การย้าย Movement/Hitbox ไป PreSimulation และความหน่วง acquisition ประมาณ 100 ms ต้องตรวจใน runtime จริงเพิ่มเติม

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

## Players directory and Spectate

`Players.spec.luau` covers the directory service, camera ownership/restoration,
target switching and disappearance, player identity, live search and UI cleanup.
`ControlCenter.spec.luau` also checks Spectate/Stop buttons and the End shortcut.
See [player tools](../docs/player-tools.md) for behavior and live acceptance checks.

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
