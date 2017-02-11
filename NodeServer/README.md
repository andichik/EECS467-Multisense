## A Node.js client for Maybot

### Why this server

With Wifi hotspot, we can use our tablet or phone to control the robot with server running on the computer.

### Tools involved

- [UrgLibrary](https://sourceforge.net/p/urgnetwork/wiki/Home/): The C library to read laser data
- [Node-ffi](https://github.com/node-ffi/node-ffi): Te bridge between C dynamic library and Node.js
- [Socket.io](socket.io): Websocket wrapper so that the server can communicate with clients
- [Express](expressjs.com): Node server to serve the files
- [Webpack](https://webpack.github.io/): Bundler to combine the front-end JS files
- [Materialize](http://materializecss.com/): Reponsive CSS libray to make the webpage look good on Mobile
- [SVG.js](https://svgdotjs.github.io/): The tool to plot SVG animations

### How to use
```
node_modules/.bin/bower install
npm install
npm run build
npm start
```
Then you can open localhost to see the result.

### Todo
- Use Webpack & npm instead of bower
- Add automation command to `npm start`
- Change implementation of laser map, use SVG `viewpoint` to do scaling and centering
- More Webpack integration[B
