import "./assets/main";

import { Elm } from "Main";

const app = Elm.Main.init({
  node: document.getElementById("app"),
});

const socket = new WebSocket("wss://echo.websocket.org");
app.ports.wsPub.subscribe((message) => {
  socket.send(message);
});
socket.addEventListener("message", (event) => {
  app.ports.wsSub.send(event.data);
});
socket.addEventListener("open", () => {
  app.ports.wsSub.send(
    JSON.stringify({
      user: 1,
      stack: ["VNC", "WebRTC"],
    })
  );
});
