const TILE_SIZE = 80;
const PIECE_SIZE = 50;

const WHITE_PAWN = 1
const WHITE_KNIGHT = 2
const WHITE_BISHOP = 3
const WHITE_ROOK = 4
const WHITE_QUEEN = 5
const WHITE_KING =  6
const BLACK_PAWN = 7
const BLACK_KNIGHT = 8
const BLACK_BISHOP = 9
const BLACK_ROOK = 10
const BLACK_QUEEN = 11
const BLACK_KING =  12

const PLAYER_WHITE = 1
const PLAYER_BLACK = 2
const PLAYER_BOTH = 3
const PLAYER_SPECTATOR = 4

class Board {
    constructor(context, socket){
        this.context = context;
        this.socket = socket;

        this.white_turn = true
        this.player_colour = PLAYER_WHITE
        this.playing = true;

        this.selectedX = -1;
        this.selectedY = -1;

        this.last_moves = [[-1,-1],[-1,-1]]

        this.load_images();
        this.assign_pieces();
    }

    load_images() {
        this.black_pawn = document.getElementById("b_pawn");
        this.black_knight = document.getElementById("b_knight");
        this.black_bishop = document.getElementById("b_bishop");
        this.black_rook = document.getElementById("b_rook");
        this.black_queen = document.getElementById("b_queen");
        this.black_king = document.getElementById("b_king");

        this.white_pawn = document.getElementById("w_pawn");
        this.white_knight = document.getElementById("w_knight");
        this.white_bishop = document.getElementById("w_bishop");
        this.white_rook = document.getElementById("w_rook");
        this.white_queen = document.getElementById("w_queen");
        this.white_king = document.getElementById("w_king");
    }

    assign_pieces(){
        this.pieces = [[],[],[],[],[],[],[],[]]

        this.pieces[0].push(WHITE_ROOK);
        this.pieces[0].push(WHITE_KNIGHT);
        this.pieces[0].push(WHITE_BISHOP);
        this.pieces[0].push(WHITE_QUEEN);
        this.pieces[0].push(WHITE_KING);
        this.pieces[0].push(WHITE_BISHOP);
        this.pieces[0].push(WHITE_KNIGHT);
        this.pieces[0].push(WHITE_ROOK);
        for (var i = 0; i < 8; i++){
            this.pieces[1].push(WHITE_PAWN);
        }

        for (var x = 0; x < 8; x++) {
            for (var y = 2; y < 6; y++){
                this.pieces[y].push(0);
            }
        }

        for (var i = 0; i < 8; i++){
            this.pieces[6].push(BLACK_PAWN);
        }
        this.pieces[7].push(BLACK_ROOK);
        this.pieces[7].push(BLACK_KNIGHT);
        this.pieces[7].push(BLACK_BISHOP);
        this.pieces[7].push(BLACK_QUEEN);
        this.pieces[7].push(BLACK_KING);
        this.pieces[7].push(BLACK_BISHOP);
        this.pieces[7].push(BLACK_KNIGHT);
        this.pieces[7].push(BLACK_ROOK);
    }

    click(e) {
        if (this.player_colour == PLAYER_SPECTATOR) return;
        
        var newX = Math.trunc(e.offsetX / TILE_SIZE);
        var newY = 7-Math.trunc(e.offsetY / TILE_SIZE);

        var can_select_white = this.white_turn && this.is_white(newX, newY) && this.player_colour != PLAYER_BLACK
        var can_select_black = !this.white_turn && this.is_black(newX, newY) && this.player_colour != PLAYER_WHITE
        if (can_select_white || can_select_black) {
            this.selectedX = newX;
            this.selectedY = newY;
        }else if(this.selectedX != -1 && this.selectedY != -1){
            this.socket.send(this.get_move_name(this.selectedX, this.selectedY, newX, newY));
        }
    }

    get_move_name(startX, startY, endX, endY) {
        return this.indices_to_name(startX, startY) + this.indices_to_name(endX, endY);
    }
    
    name_to_indices(name) {
        return [name.charCodeAt(0) - 97, name.charCodeAt(1) - 49]
    }

    indices_to_name(x, y) {
        return "abcdefgh"[x] + (y + 1)
    }

    get_piece(x, y) {
        return this.pieces[y][x];
    }

    is_white(x,y) {
        return this.get_piece(x,y) >= WHITE_PAWN && this.get_piece(x,y) <= WHITE_KING
    }
    
    is_black(x,y) {
        return this.get_piece(x,y) >= BLACK_PAWN && this.get_piece(x,y) <= BLACK_KING
    }

    get_image(x,y) {
        switch(this.get_piece(x,y)) {
            case(BLACK_PAWN):
                return this.black_pawn;
            case(BLACK_KNIGHT):
                return this.black_knight;
            case(BLACK_BISHOP):
                return this.black_bishop;
            case(BLACK_ROOK):
                return this.black_rook;
            case(BLACK_QUEEN):
                return this.black_queen;
            case(BLACK_KING):
                return this.black_king;
            case(WHITE_PAWN):
                return this.white_pawn;
            case(WHITE_KNIGHT):
                return this.white_knight;
            case(WHITE_BISHOP):
                return this.white_bishop;
            case(WHITE_ROOK):
                return this.white_rook;
            case(WHITE_QUEEN):
                return this.white_queen;
            case(WHITE_KING):
                return this.white_king;
            default:
                return new Image();
        }
    }

    loop() {
        this.draw();
        window.requestAnimationFrame(this.loop);
    }

    draw() {
        this.context.clearRect(0,0,TILE_SIZE*8,TILE_SIZE*8);

        //Tiles
        var white = true;
        for (var x = 0; x < 8; x++) {
            for(var y = 0; y < 8; y++){
                var selected = x == this.selectedX && y == this.selectedY;
                var last_moved = (x == this.last_moves[0][0] && y == this.last_moves[0][1]) ||
                 (x == this.last_moves[1][0] && y == this.last_moves[1][1]);
                this.context.fillStyle = selected ? '#74FF4A' : (last_moved ? (white ? '#e0d872' : '#c4bd58') : (white ? '#AAAAAA' : '#222222'));

                this.context.fillRect(x * TILE_SIZE, (7-y) * TILE_SIZE, TILE_SIZE, TILE_SIZE);
                this.context.fill();
                white = !white;
            }
            white = !white;
        }

        // Pieces
        for (var x = 0; x < 8; x++) {
            for(var y = 0; y < 8; y++){
                var image = this.get_image(x,y);
                var height = PIECE_SIZE;
                var width = height / image.height * image.width;
                var x_offset = (TILE_SIZE - width) / 2;
                var y_offset = (TILE_SIZE - height) / 2;
                this.context.drawImage(image, x * TILE_SIZE + x_offset, (7-y) * TILE_SIZE + y_offset, width, height);
            }
        }
    }

    receive_message(event) {
        var message = event.data

        if (message == "white wins"){
            alert("Checkmate! White wins")
            this.playing = false;
        }else if(message == "black wins"){
            alert("Checkmate! Black wins")
            this.playing = false;
        }else if(message == "draw"){
            alert("Stalemate");
            this.playing = false;
        }

        this.selectedX = -1
        this.selectedY = -1

        var [startX, startY] = this.name_to_indices(message.substring(0,2));
        var [endX, endY] = this.name_to_indices(message.substring(2));
        
        this.last_moves = [[startX, startY], [endX, endY]]

        var moved_piece = this.pieces[startY][startX]
        var removed_piece = this.pieces[endY][endX]
        this.pieces[endY][endX] = moved_piece;
        this.pieces[startY][startX] = 0;

        // Pawn Promotions
        if(moved_piece == WHITE_PAWN && endY == 7) this.pieces[endY][endX] = WHITE_QUEEN
        if(moved_piece == BLACK_PAWN && endY == 0) this.pieces[endY][endX] = BLACK_QUEEN

        // En Passant
        if((moved_piece == WHITE_PAWN || moved_piece == BLACK_PAWN) && startX != endX && removed_piece == 0) this.pieces[startY][endX] = 0

        // Castling
        if(moved_piece == WHITE_KING && startX == 4){
            if(endX == 2) {
                this.pieces[0][3] = WHITE_ROOK
                this.pieces[0][0] = 0
            } else if(endX == 6){
                this.pieces[0][5] = WHITE_ROOK
                this.pieces[0][7] = 0
            }
        }

        // Castling
        if(moved_piece == BLACK_KING && startX == 4){
            if(endX == 2) {
                this.pieces[7][3] = BLACK_ROOK
                this.pieces[7][0] = 0
            } else if(endX == 6){
                this.pieces[7][5] = BLACK_ROOK
                this.pieces[7][7] = 0
            }
        }

        this.white_turn = !this.white_turn
        this.draw();
    }

    restart_as_white(){
        this.player_colour = PLAYER_WHITE
        this.socket.send("white");
        this.restart();
    }

    restart_as_black(){
        this.player_colour = PLAYER_BLACK
        this.socket.send("black");
        this.restart();
    }
    

    restart_as_both() {
        this.player_colour = PLAYER_BOTH
        this.socket.send("both");
        this.restart();
    }

    restart_as_spectator() {
        this.player_colour = PLAYER_SPECTATOR
        this.socket.send("spectator");
        this.restart();
    }

    restart(){
        this.white_turn = true
        this.playing = true;

        this.last_moves = [[-1,-1],[-1,-1]]

        this.selectedX = -1;
        this.selectedY = -1;

        this.assign_pieces();
        this.draw()
    }
}

function mouseup(board, event) {
    board.click(event);
    board.draw();
}

function start(socket) {
    var div = document.getElementById('board')
    var canvas = document.createElement('canvas')
    canvas.width = TILE_SIZE * 8;
    canvas.height = TILE_SIZE * 8;
    div.appendChild(canvas);

    var context = canvas.getContext("2d")
    context.imageSmoothingEnabled = true;
    context.imageSmoothingQuality = "high";

    var board = new Board(context, socket);
    board.draw();

    //Add Events
    canvas.onmouseup = function(event) {mouseup(board, event)}
    socket.onclose = function() {alert("Connection lost!");};
    socket.onmessage = function(event) {board.receive_message(event)}

    document.getElementById("white_button").onclick = function() { board.restart_as_white(); };
    document.getElementById("black_button").onclick = function() { board.restart_as_black(); };
    document.getElementById("both_button").onclick = function() { board.restart_as_both(); };
    document.getElementById("spectator_button").onclick = function() { board.restart_as_spectator(); };
}

function initialise() {
    var socket = new WebSocket("ws://localhost:8080");

    console.log("Hello");

    var promises = [];
    promises.push(new Promise((resolve) => {
        window.addEventListener('load', resolve);
    }));
    promises.push(new Promise((resolve) => {
        socket.onopen = resolve;
    }))
    Promise.all(promises).then(function() {start(socket)});
}

initialise();