# Orthogonal Fills
function fill_up(position, empty)
    fill = position
    fill |= empty & (fill <<  8);
    empty &= (empty <<  8);
    fill |= empty & (fill << 16);
    empty &= (empty << 16);
    fill |= empty & (fill << 32);
    fill << 8
end

function fill_down(position, empty)
    fill = position
    fill |= empty & (fill >>  8);
    empty &= (empty >>  8);
    fill |= empty & (fill >> 16);
    empty &= (empty >> 16);
    fill |= empty & (fill >> 32);
    fill >> 8
end
function fill_left(position, empty)
    fill = position
    empty &= ~FILE_H
    fill |= empty & (fill <<  1);
    empty &= (empty <<  1) & ~FILE_H;
    fill |= empty & (fill << 2);
    empty &= (empty << 2) & ~FILE_H;
    fill |= empty & (fill << 3);
    fill << 1 & ~FILE_H
end

function fill_right(position, empty)
    fill = position
    empty &= ~FILE_A
    fill |= empty & (fill >>  1);
    empty &= (empty >>  1) & ~FILE_A;
    fill |= empty & (fill >> 2);
    empty &= (empty >> 2) & ~FILE_A;
    fill |= empty & (fill >> 3);
    fill >> 1 & ~FILE_A
end

# Diagonal Fills
function fill_up_left(position, empty)
    fill = position
    empty &= ~FILE_H
    fill |= empty & (fill <<  9);
    empty &= (empty <<  9) & ~FILE_H;
    fill |= empty & (fill << 18);
    empty &= (empty << 18) & ~FILE_H;
    fill |= empty & (fill << 27);
    fill << 9 & ~FILE_H
end

function fill_down_left(position, empty)
    fill = position
    empty &= ~FILE_H
    fill |= empty & (fill >>  7);
    empty &= (empty >>  7) & ~FILE_H;
    fill |= empty & (fill >> 14);
    empty &= (empty >> 14) & ~FILE_H;
    fill |= empty & (fill >> 21);
    fill >> 7 & ~FILE_H
end

function fill_up_right(position, empty)
    fill = position
    empty &= ~FILE_A
    fill |= empty & (fill <<  7);
    empty &= (empty <<  7) & ~FILE_A;
    fill |= empty & (fill << 14);
    empty &= (empty << 14) & ~FILE_A;
    fill |= empty & (fill << 21);
    fill << 7 & ~FILE_A
end

function fill_down_right(position, empty)
    fill = position
    empty &= ~FILE_A
    fill |= empty & (fill >>  9);
    empty &= (empty >>  9) & ~FILE_A;
    fill |= empty & (fill >> 18);
    empty &= (empty >> 18) & ~FILE_A;
    fill |= empty & (fill >> 27);
    fill >> 9 & ~FILE_A
end