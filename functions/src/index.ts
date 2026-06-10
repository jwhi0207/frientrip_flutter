import { onDocumentCreated } from "firebase-functions/v2/firestore";
import * as logger from "firebase-functions/logger";
import { initializeApp } from "firebase-admin/app";
import { getFirestore, FieldValue } from "firebase-admin/firestore";
import { getMessaging } from "firebase-admin/messaging";

initializeApp();

export const onNewMessage = onDocumentCreated(
  "trips/{tripId}/messages/{messageId}",
  async (event) => {
    const snapshot = event.data;
    if (!snapshot) return;

    const messageData = snapshot.data();
    const tripId = event.params.tripId;
    const senderUid = messageData.senderUid as string;
    const senderName = messageData.senderName as string;

    // Skip notifications for soft-deleted messages
    if (messageData.deleted === true) return;

    const db = getFirestore();

    // 1. Get all active members of the trip
    const membersSnap = await db
      .collection("trips")
      .doc(tripId)
      .collection("members")
      .where("status", "==", "active")
      .get();

    // 2. Filter out: sender, muted members, guests
    const recipientUids = membersSnap.docs
      .filter((doc) => {
        const data = doc.data();
        return (
          doc.id !== senderUid &&
          data.mutedMessages !== true &&
          data.isGuest !== true
        );
      })
      .map((doc) => doc.id);

    logger.info("onNewMessage", {
      tripId,
      senderUid,
      activeMembers: membersSnap.size,
      recipients: recipientUids.length,
    });

    if (recipientUids.length === 0) {
      logger.info("No recipients after filtering — nothing to send", { tripId });
      return;
    }

    // 3. Get FCM tokens for all recipients
    const userDocs = await Promise.all(
      recipientUids.map((uid) => db.collection("users").doc(uid).get())
    );

    const tokens: string[] = [];
    for (const userDoc of userDocs) {
      if (!userDoc.exists) continue;
      const fcmTokens = userDoc.data()?.fcmTokens;
      if (Array.isArray(fcmTokens)) {
        tokens.push(...fcmTokens);
      }
    }

    if (tokens.length === 0) {
      logger.warn("Recipients have no FCM tokens — nothing to send", {
        tripId,
        recipients: recipientUids,
      });
      return;
    }

    // 4. Get trip name for the notification body
    const tripDoc = await db.collection("trips").doc(tripId).get();
    const tripName = tripDoc.data()?.name ?? "Trip";

    // 5. Build notification content (announcements get special formatting)
    const isAnnouncement = messageData.isAnnouncement === true;
    const notifTitle = isAnnouncement ? "Announcement" : "New Message!";
    const notifBody = isAnnouncement
      ? `${messageData.text}`
      : `${senderName} sent a message in ${tripName}`;

    // 6. Send FCM notifications
    const messaging = getMessaging();
    const response = await messaging.sendEachForMulticast({
      tokens,
      notification: {
        title: notifTitle,
        body: notifBody,
      },
      data: {
        tripId: tripId,
        type: "new_message",
      },
      android: {
        priority: "high",
      },
      apns: {
        payload: {
          aps: {
            sound: "default",
          },
        },
      },
    });

    logger.info("FCM send complete", {
      tripId,
      tokens: tokens.length,
      success: response.successCount,
      failure: response.failureCount,
    });
    response.responses.forEach((resp, idx) => {
      if (resp.error) {
        logger.warn("FCM send error", {
          tokenSuffix: tokens[idx].slice(-8),
          code: resp.error.code,
          message: resp.error.message,
        });
      }
    });

    // 7. Clean up stale/invalid tokens
    const tokensToRemove: { uid: string; token: string }[] = [];
    response.responses.forEach((resp, idx) => {
      if (resp.error) {
        const code = resp.error.code;
        if (
          code === "messaging/invalid-registration-token" ||
          code === "messaging/registration-token-not-registered"
        ) {
          const badToken = tokens[idx];
          for (const userDoc of userDocs) {
            const fcmTokens = userDoc.data()?.fcmTokens ?? [];
            if (Array.isArray(fcmTokens) && fcmTokens.includes(badToken)) {
              tokensToRemove.push({ uid: userDoc.id, token: badToken });
              break;
            }
          }
        }
      }
    });

    if (tokensToRemove.length > 0) {
      logger.info("Removing stale tokens", { count: tokensToRemove.length });
      await Promise.all(
        tokensToRemove.map(({ uid, token }) =>
          db.collection("users").doc(uid).update({
            // arrayRemove is variadic in the admin SDK — passing [token]
            // would try to remove a nested array element
            fcmTokens: FieldValue.arrayRemove(token),
          })
        )
      );
    }
  }
);
