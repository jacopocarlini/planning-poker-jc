importScripts("https://www.gstatic.com/firebasejs/9.19.1/firebase-app-compat.js");
importScripts("https://www.gstatic.com/firebasejs/9.19.1/firebase-messaging-compat.js");

firebase.initializeApp({

   apiKey: 'AIzaSyD5HHrk2VIyrQNqC0PFG8D_NztW5lifGR8',
      appId: '1:52504714204:web:c101eeba0977c8d44b8d19',
      messagingSenderId: '52504714204',
      projectId: 'poker-planning-jc',
      authDomain: 'poker-planning-jc.firebaseapp.com',
      databaseURL: 'https://poker-planning-jc-default-rtdb.europe-west1.firebasedatabase.app',
      storageBucket: 'poker-planning-jc.firebasestorage.app',
      measurementId: 'G-9TZRGRK4JG',
});

const messaging = firebase.messaging();

// Handle background messages
messaging.onBackgroundMessage(async (payload) => {
  console.log('Received background message:', payload);

  const notificationTitle = payload.notification.title;
  const notificationOptions = {
    body: payload.notification.body,
    icon: '/icons/Icon-192.png',
    badge: '/icons/Icon-192.png',
    data: payload.data,
    click_action: payload.notification.click_action,
  };

  self.registration.showNotification(notificationTitle, notificationOptions);
});