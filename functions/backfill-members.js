const { initializeApp, applicationDefault } = require("firebase-admin/app");
const { getFirestore } = require("firebase-admin/firestore");

initializeApp({ credential: applicationDefault() });
const db = getFirestore();

async function main() {
  const trips = await db.collection("trips").get();
  console.log(`Found ${trips.size} trips\n`);

  let updated = 0;

  for (const trip of trips.docs) {
    const tripName = trip.data().name || trip.id;
    const members = await db
      .collection("trips")
      .doc(trip.id)
      .collection("members")
      .get();

    for (const member of members.docs) {
      const data = member.data();
      const patch = {};

      if (!("status" in data)) patch.status = "active";
      if (!("mutedMessages" in data)) patch.mutedMessages = false;
      if (!("isGuest" in data)) patch.isGuest = false;

      if (Object.keys(patch).length > 0) {
        await member.ref.update(patch);
        console.log(
          `  Patched ${member.id} in "${tripName}" — added: ${Object.keys(patch).join(", ")}`
        );
        updated++;
      }
    }
  }

  console.log(`\nDone. Updated ${updated} member documents.`);
}

main().catch(console.error);
