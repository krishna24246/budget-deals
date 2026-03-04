 Overview
Brief description of the main workflow.

 User Flows

 1. Authentication Flow
Description: How users sign up and log in

Steps:
1. User opens app → Splash screen loads
2. Check for existing session
3. If no session → Navigate to Login screen
4. User clicks "Sign in with Google"
5. Firebase Auth processes credentials
6. On success → Create/update user document in Firestore
7. Navigate to Home screen

 2. Deal Discovery Flow
Description: How users browse and find deals

steps:
1. Home screen loads → Fetch active deals from Firestore
2. Display deals in scrollable list with category filters
3. User can search by keyword
4. User taps deal → Navigate to Deal Details
5. User can save deal to wishlist

 3. Wishlist Management Flow
Description: How users manage saved deals

Steps:
1. User navigates to Wishlist tab
2. Fetch user's wishlist items from Firestore
3. Display saved deals with latest prices
4. User can remove items or view deal details

 Admin Flows

 4. Deal Management Flow (Admin)
Description: How admins create/edit/delete deals

Steps:
1. Admin logs in with admin account
2. Access Admin Panel from profile menu
3. Create new deal → Fill form → Save to Firestore
4. Edit existing deal → Update fields → Save
5. Delete deal → Soft delete (set isActive: false)

 System Flows

 5. Notification Flow
Description: How push notifications work

Steps:
1. App starts → Request notification permissions
2. Register device token with Firestore
3. Admin creates hot deal → Trigger Cloud Function
4. Cloud Function sends FCM to subscribed users
5. User receives push notification
