const {getApps, initializeApp} = require("firebase-admin/app");
const {GeoPoint, Timestamp, getFirestore} = require("firebase-admin/firestore");

if (!process.env.FIRESTORE_EMULATOR_HOST) {
  throw new Error("seed:emulator 只能在 Firestore Emulator 中執行。");
}

if (getApps().length === 0) {
  initializeApp({projectId: "food-9a095"});
}

const db = getFirestore();
const now = Date.now();
const restaurants = [
  {
    id: "a-cai-oyster-noodles",
    name: "阿財蚵仔麵線",
    address: "台北市大同區民生西路198號",
    latitude: 25.0575,
    longitude: 121.5124,
    categories: ["小吃", "中式"],
    dishes: ["蚵仔麵線", "大腸麵線"],
  },
  {
    id: "isari-japanese-dining",
    name: "漁火日式食堂",
    address: "台北市中山區南京東路二段115巷3弄2號",
    latitude: 25.0522,
    longitude: 121.5339,
    categories: ["日式"],
    dishes: ["炙燒鮭魚丼", "唐揚雞"],
  },
  {
    id: "seoul-kitchen",
    name: "首爾小館",
    address: "台北市大安區忠孝東路四段216巷27弄6號",
    latitude: 25.0409,
    longitude: 121.5531,
    categories: ["韓式"],
    dishes: ["韓式烤肉", "海鮮煎餅"],
  },
  {
    id: "old-shanghai-home-cooking",
    name: "老上海家常菜",
    address: "台北市松山區八德路三段12巷5弄8號",
    latitude: 25.0476,
    longitude: 121.5517,
    categories: ["中式"],
    dishes: ["紅燒獅子頭", "菜飯"],
  },
  {
    id: "hill-italian-kitchen",
    name: "山丘義式廚房",
    address: "台北市信義區松壽路20號",
    latitude: 25.0356,
    longitude: 121.5671,
    categories: ["西式"],
    dishes: ["松露野菇燉飯", "瑪格麗特披薩"],
  },
  {
    id: "siam-spice-kitchen",
    name: "暹羅香料廚房",
    address: "台北市中正區羅斯福路三段316巷8弄3號",
    latitude: 25.0152,
    longitude: 121.5329,
    categories: ["東南亞料理"],
    dishes: ["打拋豬", "綠咖哩雞"],
  },
  {
    id: "warm-hot-pot",
    name: "暖暖鍋物",
    address: "台北市萬華區成都路17號",
    latitude: 25.0425,
    longitude: 121.5071,
    categories: ["火鍋"],
    dishes: ["昆布鍋", "麻辣鍋"],
  },
  {
    id: "charcoal-town-bbq",
    name: "炭火町燒烤",
    address: "台北市中山區林森北路119巷40號",
    latitude: 25.0507,
    longitude: 121.5258,
    categories: ["燒烤", "日式"],
    dishes: ["鹽烤雞腿串", "烤鯖魚"],
  },
  {
    id: "afternoon-dessert-room",
    name: "午後甜室",
    address: "台北市大安區永康街31巷14號",
    latitude: 25.0308,
    longitude: 121.5295,
    categories: ["甜點"],
    dishes: ["焦糖布丁", "季節水果塔"],
  },
  {
    id: "island-tea-lab",
    name: "島嶼茶作",
    address: "台北市士林區文林路101巷12號",
    latitude: 25.0881,
    longitude: 121.5252,
    categories: ["飲料"],
    dishes: ["四季春茶", "黑糖珍珠鮮奶"],
  },
];

async function seed() {
  const writer = db.bulkWriter();
  restaurants.forEach((restaurant, index) => {
    const reference = db.collection("restaurants").doc(restaurant.id);
    const createdAt = Timestamp.fromMillis(now - index * 60 * 60 * 1000);
    const coverPhotoUrl =
      `https://picsum.photos/seed/${restaurant.id}-cover/900/600`;
    writer.set(reference, {
      name: restaurant.name,
      nameLower: restaurant.name.toLowerCase(),
      nameNormalized: restaurant.name.toLowerCase().replaceAll(/\s+/g, ""),
      address: restaurant.address,
      geo: new GeoPoint(restaurant.latitude, restaurant.longitude),
      geohash: encodeGeohash(restaurant.latitude, restaurant.longitude),
      categories: restaurant.categories,
      recommendedDishes: restaurant.dishes,
      coverPhotoUrl,
      photoCount: 2,
      ratingSum: 9,
      ratingCount: 2,
      reportCount: 0,
      favoriteCount: 12 + index,
      status: "active",
      createdBy: "seed-user",
      createdAt,
      updatedAt: createdAt,
    });

    ["one", "two"].forEach((suffix, photoIndex) => {
      writer.set(reference.collection("photos").doc(`seed-photo-${suffix}`), {
        url: `https://picsum.photos/seed/${restaurant.id}-${suffix}/800/600`,
        storagePath: `seed/${restaurant.id}/${suffix}.jpg`,
        uploadedBy: "seed-user",
        createdAt: Timestamp.fromMillis(createdAt.toMillis() + photoIndex),
        status: "active",
        reportCount: 0,
      });
    });

    writer.set(reference.collection("reviews").doc("seed-reviewer-one"), {
      rating: 5,
      text: `很喜歡${restaurant.dishes[0]}，會再回訪。`,
      authorUid: "seed-reviewer-one",
      authorName: "Emulator 小美",
      authorPhotoUrl: null,
      status: "active",
      reportCount: 0,
      createdAt,
      updatedAt: createdAt,
    });
    writer.set(reference.collection("reviews").doc("seed-reviewer-two"), {
      rating: 4,
      text: "環境舒服，餐點表現穩定。",
      authorUid: "seed-reviewer-two",
      authorName: "Emulator 阿明",
      authorPhotoUrl: null,
      status: "active",
      reportCount: 0,
      createdAt,
      updatedAt: createdAt,
    });
  });

  writer.set(db.collection("restaurants").doc("old-island-tea-lab"), {
    name: "舊島嶼茶作",
    nameLower: "舊島嶼茶作",
    nameNormalized: "舊島嶼茶作",
    address: "台北市士林區文林路99號",
    geo: new GeoPoint(25.088, 121.525),
    geohash: encodeGeohash(25.088, 121.525),
    categories: ["飲料"],
    recommendedDishes: [],
    coverPhotoUrl: null,
    photoCount: 0,
    ratingSum: 0,
    ratingCount: 0,
    reportCount: 0,
    favoriteCount: 0,
    status: "merged",
    mergedIntoRestaurantId: "island-tea-lab",
    createdBy: "seed-user",
    createdAt: Timestamp.fromMillis(now - 24 * 60 * 60 * 1000),
    updatedAt: Timestamp.fromMillis(now),
  });
  writer.set(db.collection("restaurants").doc("removed-seed-restaurant"), {
    name: "已移除測試店家",
    nameLower: "已移除測試店家",
    nameNormalized: "已移除測試店家",
    address: "台北市測試路0號",
    geo: new GeoPoint(25.04, 121.52),
    geohash: encodeGeohash(25.04, 121.52),
    categories: ["小吃"],
    recommendedDishes: [],
    coverPhotoUrl: null,
    photoCount: 0,
    ratingSum: 0,
    ratingCount: 0,
    reportCount: 0,
    favoriteCount: 0,
    status: "removed",
    createdBy: "seed-user",
    createdAt: Timestamp.fromMillis(now - 48 * 60 * 60 * 1000),
    updatedAt: Timestamp.fromMillis(now),
  });
  await writer.close();
}

function encodeGeohash(latitude, longitude, precision = 9) {
  const alphabet = "0123456789bcdefghjkmnpqrstuvwxyz";
  let latitudeRange = [-90, 90];
  let longitudeRange = [-180, 180];
  let result = "";
  let bit = 0;
  let character = 0;
  let even = true;

  while (result.length < precision) {
    const range = even ? longitudeRange : latitudeRange;
    const coordinate = even ? longitude : latitude;
    const midpoint = (range[0] + range[1]) / 2;
    if (coordinate >= midpoint) {
      character = character * 2 + 1;
      range[0] = midpoint;
    } else {
      character *= 2;
      range[1] = midpoint;
    }
    even = !even;
    bit += 1;
    if (bit === 5) {
      result += alphabet[character];
      bit = 0;
      character = 0;
    }
  }
  return result;
}

seed()
  .then(() => {
    process.stdout.write(
      `Seeded ${restaurants.length} active restaurants into Emulator.\n`,
    );
  })
  .catch((error) => {
    process.stderr.write(`${error.stack ?? error}\n`);
    process.exitCode = 1;
  });
