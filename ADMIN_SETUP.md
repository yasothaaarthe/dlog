# DLog admin prototype setup

The admin dashboard reads real Firebase documents. It does not seed sample users, vehicles, service records, or support tickets.

## Enable an admin account

1. Create a normal account in DLog and sign in once.
2. In Firebase Console, open **Firestore Database** and find `users/{your-auth-uid}`. The UID is available under **Authentication → Users**.
3. Change that document's `role` field from `user` to `admin` (string value).
4. Sign out of DLog and sign in again. The login screen routes that account to the admin dashboard.

Do not add an in-app role editor or allow users to promote themselves. The role field is a prototype navigation gate only. Before production, enforce admin access in Firestore Security Rules or verified custom claims; client-side routing alone does not secure database data.

## Support tickets

A signed-in user can open **SOS → DLog App Support → Report an app issue**. The first successful submission creates the `supportTickets` collection automatically. Admins can filter tickets and update a ticket to Open, In Progress, or Resolved.
