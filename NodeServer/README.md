## A Node.js client for Maybot

### Update

- When writing code, try using `ESLint` to lint your code to eliminate most of the trivial bugs. The lint file is in the repository.

### Why this server

With Wifi hotspot, we can use our tablet or phone to control the robot with server running on the computer.

### Libraries involved

- [UrgLibrary](https://sourceforge.net/p/urgnetwork/wiki/Home/): The C library to read laser data
- [Node-ffi](https://github.com/node-ffi/node-ffi): Te bridge between C dynamic library and Node.js
- [Socket.io](socket.io): Websocket wrapper so that the server can communicate with clients
- [Express](expressjs.com): Node server to serve the files
- [Webpack](https://webpack.github.io/): Bundler to combine the front-end JS files
- [Materialize](http://materializecss.com/): Reponsive CSS libray to make the webpage look good on Mobile
- [SVG.js](https://svgdotjs.github.io/): The tool to plot SVG animations

### How to use
```
npm install
```

Use terminal multiplexer like `tmux` of `byobu` or just opne two terminal instances, in a window input `npm run build`, where Webpack will now watch the files and start automatically building. In another type `npm start`, where the server is started.
Then you can open localhost to see the result.

### Todo

- Delete current updatePose
- Minify code

Things after:
- Integration
- PID control to go to one point, and parse the path given by A-Star
