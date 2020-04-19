import "./assets/main";

import { Elm } from "Main";

const app = Elm.Main.Init();
app.ports.updates.subscribe((data) => console.log(data));
