1️⃣ FINAL correct Firestore rules (paste once, no duplicates)
2️⃣ Why your PERMISSION_DENIED error is happening
3️⃣ How admin upload should work (simple + fast text paste)
4️⃣ Full professional feature list (Admin + User + App-wide)
5️⃣ Theme, login persistence, and profile fixes explained clearly

✅ 1️⃣ FINAL FIRESTORE RULES (COPY–PASTE THIS ONLY)

❌ Do NOT paste rules twice
❌ Remove the global allow read: if true block
✅ Use this single file only

rules_version = '2';
service cloud.firestore {
  match /databases/{database}/documents {

    // ---------------- USERS ----------------
    match /users/{userId} {
      allow read, write: if request.auth != null && request.auth.uid == userId;
    }

    // ---------------- ADMINS ----------------
    match /admins/{userId} {
      allow read: if request.auth != null && request.auth.uid == userId;
      allow write: if request.auth != null &&
        get(/databases/$(database)/documents/admins/$(request.auth.uid)).data.role == 'admin';
    }

    // ---------------- DEALS ----------------
    match /deals/{dealId} {

      // Users can read deals (logged in)
      allow read: if request.auth != null;

      // ONLY ADMINS CAN WRITE
      allow create, update, delete: if request.auth != null &&
        exists(/databases/$(database)/documents/admins/$(request.auth.uid));
    }

    // ---------------- SAVED DEALS ----------------
    match /saved/{userId}/{dealId} {
      allow read, write: if request.auth != null && request.auth.uid == userId;
    }

    // ---------------- CATEGORIES ----------------
    match /categories/{categoryId} {
      allow read: if request.auth != null;
      allow write: if request.auth != null &&
        exists(/databases/$(database)/documents/admins/$(request.auth.uid));
    }

    // ---------------- DEFAULT BLOCK ----------------
    match /{document=**} {
      allow read, write: if false;
    }
  }
}


📌 After pasting → click PUBLISH

❗ 2️⃣ WHY YOU ARE GETTING PERMISSION_DENIED

Error:

Missing or insufficient permissions

This happens because:

Your logged-in user is NOT registered as admin

Firestore rules correctly block non-admin writes

✅ FIX (VERY IMPORTANT)

Go to Firestore → admins collection

Create document:

Collection: admins
Document ID: YOUR_FIREBASE_AUTH_UID
Field:
  role : "admin"


📌 UID = Firebase Auth → Users → copy UID
📌 Must match logged-in admin account

After this → Add Deal WILL WORK

✅ 3️⃣ ADMIN PANEL – FAST TEXT PASTE (NO FORMS)

You said:

“I want direct text upload, not filling many fields”

✅ NEW DEAL MODEL (SIMPLE)

Admin pastes raw deal text, example:

🔥 iPhone 13 @ ₹42,999
Flipkart Offer 🎉
Link: https://fkrt.in/xyz
Bank offer available

Firestore Deal Document
{
  "rawText": "🔥 iPhone 13 @ ₹42,999 ...",
  "title": "iPhone 13",
  "category": "Mobiles",
  "link": "https://fkrt.in/xyz",
  "isHot": true,
  "isTrending": false,
  "isPinned": false,
  "isArchived": false,
  "createdAt": serverTimestamp(),
  "updatedAt": serverTimestamp()
}


👉 All other fields OPTIONAL
👉 No price / discount required
👉 You save time

🧠 4️⃣ ADMIN PANEL FEATURES (PROFESSIONAL)
🛠 Deal Management

Admin can:

✅ Paste full deal text

✅ Edit pasted text

✅ Edit title (optional)

✅ Change category

✅ Update link

✅ Toggle Hot

✅ Toggle Trending

✅ Pin / Unpin deal

✅ Archive deal (NOT delete)

✅ Restore archived deal

📌 Archive = safer than delete

👤 5️⃣ USER APP FEATURES (PROFESSIONAL)
🏠 Home

Latest deals

Pinned deals on top

Hot badge

Infinite scroll

🔥 Trending

Deals with isTrending == true

Sorted by engagement

📂 Categories

Filter by category

Count badges

❤️ Saved

User saved deals

Offline support

👤 Profile

Theme toggle (Dark / Light)

Logout

App version

Support / Help

❌ Remove:

Bio

Manual email editing

📌 Email should show Auth email automatically

🌗 6️⃣ THEME SYSTEM (DARK / LIGHT – ALL SCREENS)
Use:

Firebase / SharedPreferences / Provider

ThemeMode.dark
ThemeMode.light
ThemeMode.system

Rules:

If dark → ALL screens dark

If light → ALL screens light

Save preference locally

Apply on app restart

🔐 7️⃣ LOGIN BEHAVIOR (NO RE-LOGIN)
Correct behavior:

User logs in ONCE

Firebase Auth persists session

App checks currentUser != null

Skip login screen

❌ No “Continue without account”
✔ Mandatory login = better security

🔔 8️⃣ NOTIFICATIONS (HOT DEALS)

Trigger when:

isHot == true

Use:

Firebase Cloud Messaging (later)

Filter:

Category-based notifications

🤖 9️⃣ DEEPSEEK – SIMPLE & USEFUL WAY

Forget “search engine replacement” ❌
Use DeepSeek for:

✅ User Support Chat

“What is this deal?”

“Is this genuine?”

“Explain bank offer”

✅ Deal Explanation

Send rawText → DeepSeek → short explanation

📌 No scraping
📌 No complex indexing
📌 Easy to implement later

🎯 FINAL SUMMARY

You should now:

1️⃣ Paste FINAL Firestore rules
2️⃣ Add yourself to admins collection
3️⃣ Use raw text deal upload
4️⃣ Archive instead of delete
5️⃣ Enable dark/light theme globally
6️⃣ Trust Firebase Auth for login persistence