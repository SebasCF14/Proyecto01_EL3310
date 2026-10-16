# Proyecto 1 - Diseño de Sistemas Digitales (Pong RISC-V - RARS)

# ==============================================================
# CONTROLES:
#     Jugador 1 (izquierda): W = Sube | A = Baja
#     Jugador 2 (derecha)  : D = Sube | S = Baja
#     Pantalla de Inicio   : 1 = Comenzar
# ==============================================================

.eqv SCREEN_WIDTH, 64
.eqv SCREEN_HEIGHT, 32
.eqv TOTAL_PIXEL, 8192      # 64 * 32 * 4 bytes

.eqv TITLE_SCREEN_FIRST_LINE_ROW_Y, 1
.eqv TITLE_SCREEN_SECOND_LINE_ROW_Y, 12

.eqv PONG_TEXT_X, 21
.eqv PONG_TEXT_Y, 5
.eqv PONG_TEXT_H, 5

.eqv PRESS_TEXT_X, 20
.eqv PRESS_TEXT_Y, 16
.eqv PRESS_TEXT_H, 4

.eqv KEY_STATUS_ADDRESS, 0xFFFF0000
.eqv KEY_INPUT_ADDRESS,  0xFFFF0004

.eqv MOV_UP, 1
.eqv MOV_DOWN, 2
.eqv MOV_STAY, 0

.eqv INITIAL_PADDLE_POSITION, 13
.eqv INITIAL_BALL_X_POS, 32
.eqv INITIAL_BALL_Y_POS, 15

.eqv P1_SCORE_COLUMN, 25
.eqv P2_SCORE_COLUMN, 36
.eqv SCORE_Y, 1
.eqv SCORE_DASH_X, 30
.eqv SCORE_DASH_END_X, 33
.eqv SCORE_DASH_Y, 3
.eqv GAME_WIN_POINTS, 10

.eqv PADDLE_LENGTH, 5
.eqv TOP_PADDLE_Y_ROW, 0
.eqv BOTTOM_PADDLE_Y_ROW, 26

.eqv PLAYER_1_PADDLE_X_POS, 2
.eqv PLAYER_2_PADDLE_X_POS, 61

.eqv FIRST_COLUMN, 0
.eqv LAST_COLUMN, 63

.eqv BALL_RIGHT_DIR, 1
.eqv BALL_LEFT_DIR, -1
.eqv BALL_UP_DIR, -1
.eqv BALL_DOWN_DIR, 1

.eqv BALL_Y_VELOCITY_REDUCTION, -1

.eqv LEFT_COLLISION_X_POS, 3
.eqv RIGHT_COLLISION_X_POS, 60

.eqv TOP_HIGH, 0
.eqv TOP_MID, 1
.eqv TOP_LOW, 2
.eqv BOTTOM_HIGH, 3
.eqv BOTTOM_MID, 4
.eqv BOTTOM_LOW, 5

.eqv Y_DOWN_LIMIT, 31
.eqv Y_UP_LIMIT, 0
.eqv Y_MAX_COLLISION_VELOCITY, 1

.eqv ASCII_1, 0x31

.eqv KEY_P1_UP, 119    # 'w'
.eqv KEY_P1_DOWN, 97    # 'a'
.eqv KEY_P2_UP, 115     # 'd'
.eqv KEY_P2_DOWN, 100   # 's'

.eqv P_CHAR_WIN_X, 26
.eqv P_CHAR_WIN_Y, 5
.eqv P_CHAR_WIN_H, 5

.eqv PLAYER_NUM_WIN_X, 33
.eqv PLAYER_NUM_WIN_Y, 5
.eqv PLAYER_NUM_WIN_H, 5

.eqv WINS_TEXT_X, 21
.eqv WINS_TEXT_Y, 16
.eqv WINS_TEXT_H, 5

.data 
	color_white:	.word 0x00ffffff
	color_black:	.word 0x00000000
	color_red:	    .word 0x00ff0000
	color_cyan: 	.word 0x0000ffff
	color_orange:	.word 0x00ffa500
	
	player_mode:	.word 0
	ball_x_dir:	    .word BALL_RIGHT_DIR
	ball_y_speed:	.word -1	
	ball_y_dir:	    .word -1	
	p1_score:	    .word 0
	p2_score: 	    .word 0
	computer_count:	.word 0
	computer_speed:	.word 0		
	level:		    .word 6

.text
.globl main

main:
	li gp, 0x10040000   # Direccion base de la memoria del Bitmap Display

new_game:
	call clear_board
	call draw_title_screen
	
select_2_players:
	li t0, KEY_STATUS_ADDRESS
	lw t0, 0(t0)
	blez t0, .wait_input        
	
	li t0, KEY_INPUT_ADDRESS
	lw t0, 0(t0)
	li t1, ASCII_1
	beq t0, t1, two_player_mode
	
.wait_input:
	li a0, 250
	li a7, 32
	ecall
	j select_2_players          

two_player_mode:
	li t0, 2
	la t1, player_mode
	sw t0, 0(t1)
	call clear_key_press
	j new_round	

new_round:
	li t0, 1
	la t1, ball_y_speed
	sw t0, 0(t1)
	
	li t0, -1
	la t1, ball_y_dir
	sw t0, 0(t1)
	
	la t1, computer_speed
	sw zero, 0(t1)
	
	la t1, computer_count
	sw zero, 0(t1)
	
	li s0, MOV_STAY
	li s1, MOV_STAY
	
	la t1, ball_x_dir
	lw s2, 0(t1)
	
	la t1, ball_y_speed
	lw s3, 0(t1)
	
	li s4, INITIAL_PADDLE_POSITION
	li s5, INITIAL_PADDLE_POSITION
	li s6, INITIAL_BALL_X_POS
	li s7, INITIAL_BALL_Y_POS
	
	call clear_board
	jal draw_score          
	
	li a0, PLAYER_1_PADDLE_X_POS
	mv a1, s4
	la t0, color_red
	lw a2, 0(t0)
	li a3, MOV_STAY
	jal draw_paddle
	
	li a0, PLAYER_2_PADDLE_X_POS 
	mv a1, s5
	la t0, color_red
	lw a2, 0(t0)
	li a3, MOV_STAY
	jal draw_paddle
	
	li a0, 1000
	li a7, 32		
	ecall		# Pausa de 1 segundo antes de iniciar la ronda

main_game_loop:
	jal check_collisions
	
	# Verificar si la bola rebaso los bordes
	li t0, FIRST_COLUMN
	beq s6, t0, p1_loses_round
	li t0, LAST_COLUMN
	beq s6, t0, p2_loses_round

	jal move_ball
	
	li a0, PLAYER_1_PADDLE_X_POS
	mv a1, s4
	la t0, color_red
	lw a2, 0(t0)
	mv a3, s0
	jal draw_paddle
	mv s4, a0
	mv s0, a1

	li a0, PLAYER_2_PADDLE_X_POS
	mv a1, s5
	la t0, color_red
	lw a2, 0(t0)
	mv a3, s1
	jal draw_paddle
	mv s5, a0
	mv s1, a1

.begin_standby:
	li a0, 40             
	li a7, 32
	ecall		
	li s0, MOV_STAY
	li s1, MOV_STAY
	
.drain_input:
	li t2, KEY_STATUS_ADDRESS
	lw t1, 0(t2)
	blez t1, .end_standby    
	
	jal adjust_dir          
	j .drain_input          

.end_standby:
	j main_game_loop
	
adjust_dir:
	li t2, KEY_INPUT_ADDRESS
	lw t0, 0(t2)
	ori t0, t0, 0x20        

.adjust_dir_p1_up:
	li t1, KEY_P1_UP
	bne t0, t1, .adjust_dir_p1_down
	li s0, MOV_UP
	j .adjust_dir_done

.adjust_dir_p1_down:
	li t1, KEY_P1_DOWN
	bne t0, t1, .adjust_dir_p2_up
	li s0, MOV_DOWN
	j .adjust_dir_done

.adjust_dir_p2_up:
	li t1, KEY_P2_UP
	bne t0, t1, .adjust_dir_p2_down
	li s1, MOV_UP
	j .adjust_dir_done

.adjust_dir_p2_down:
	li t1, KEY_P2_DOWN
	bne t0, t1, .adjust_dir_done
	li s1, MOV_DOWN

.adjust_dir_done:
	jalr zero, ra, 0

check_collisions:
	li t0, LEFT_COLLISION_X_POS
	beq s6, t0, .left_collision
	
	li t0, RIGHT_COLLISION_X_POS
	beq s6, t0, .right_collision
	
	j .no_paddle_collision
	
.left_collision:
	blt s7, s4, .no_paddle_collision
	li t0, PADDLE_LENGTH
	addi t0, t0, -1
	add t0, s4, t0 
	bgt s7, t0, .no_paddle_collision
	sub t2, s7, s4		
	li s2, BALL_RIGHT_DIR
	j .paddle_hit            
	
.right_collision:
	blt s7, s5, .no_paddle_collision
	li t0, PADDLE_LENGTH
	addi t0, t0, -1
	add t0, s5, t0
	bgt s7, t0, .no_paddle_collision
	sub t2, s7, s5		
	li s2, BALL_LEFT_DIR 
	j .paddle_hit            
	
.no_paddle_collision:
	j .check_horizontal_hit

.paddle_hit:                 
	la t1, level
	lw t0, 0(t1)
	la t1, computer_speed
	sw t0, 0(t1)

	mv t0, t2
	li t1, TOP_HIGH
	beq t0, t1, .top_high
	li t1, TOP_MID
	beq t0, t1, .top_mid
	li t1, TOP_LOW
	beq t0, t1, .top_low
	li t1, BOTTOM_HIGH
	beq t0, t1, .bottom_high
	li t1, BOTTOM_MID
	beq t0, t1, .bottom_mid
	li t1, BOTTOM_LOW
	beq t0, t1, .bottom_low

.top_high:
	li s3, TOP_HIGH
	la t1, ball_y_speed
	sw s3, 0(t1)
	li s3, BALL_UP_DIR
	la t1, ball_y_dir
	sw s3, 0(t1)
	j .check_horizontal_hit

.top_mid:
	li s3, TOP_MID
	la t1, ball_y_speed
	sw s3, 0(t1)
	li s3, BALL_UP_DIR
	la t1, ball_y_dir
	sw s3, 0(t1)
	j .check_horizontal_hit

.top_low:
	li s3, TOP_LOW
	la t1, ball_y_speed
	sw s3, 0(t1)
	li s3, BALL_UP_DIR
	la t1, ball_y_dir
	sw s3, 0(t1)
	j .check_horizontal_hit

.bottom_high:
	li s3, BOTTOM_HIGH
	la t1, ball_y_speed
	sw s3, 0(t1)
	li s3, BALL_DOWN_DIR
	la t1, ball_y_dir
	sw s3, 0(t1)
	j .check_horizontal_hit

.bottom_mid:
	li s3, BOTTOM_MID
	la t1, ball_y_speed
	sw s3, 0(t1)
	li s3, BALL_DOWN_DIR
	la t1, ball_y_dir
	sw s3, 0(t1)
	j .check_horizontal_hit

.bottom_low:
	li s3, BOTTOM_LOW
	la t1, ball_y_speed
	sw s3, 0(t1)
	li s3, BALL_DOWN_DIR
	la t1, ball_y_dir
	sw s3, 0(t1)
	j .check_horizontal_hit

.check_horizontal_hit:
	li t0, Y_DOWN_LIMIT
	beq s7, t0, .horizontal_wall_hit
	li t0, Y_UP_LIMIT
	bne s7, t0, .no_collision

.horizontal_wall_hit:
	li t0, Y_MAX_COLLISION_VELOCITY
	bgt s3, t0, .no_collision
	la t1, ball_y_dir
	lw t0, 0(t1)
	sub t0, zero, t0
	sw t0, 0(t1)
	
.no_collision:
	jalr zero, ra, 0

move_ball:
	addi sp, sp, -4
	sw ra, 0(sp)
	
	mv a0, s6
	mv a1, s7
	la t0, color_black
	lw a2, 0(t0)
	call draw_point          

	li t0, 6
	bgt s7, t0, .skip_score_redraw
	call draw_score
.skip_score_redraw:
	
	add s6, s6, s2 
	li t0, BALL_Y_VELOCITY_REDUCTION
	add s3, s3, t0
	bgt s3, zero, .no_y_change
	
.change_y:
	la t1, ball_y_dir
	lw t0, 0(t1)
	add s7, s7, t0
	la t1, ball_y_speed
	lw s3, 0(t1)

.no_y_change:
	mv a0, s6
	mv a1, s7
	la t0, color_white
	lw a2, 0(t0)
	call draw_point          
		
	lw ra, 0(sp)
	addi sp, sp, 4
	jalr zero, ra, 0

p1_loses_round:
	la t1, p2_score
	lw t0, 0(t1)
	addi t0, t0, 1
	sw t0, 0(t1)
		
	li t0, BALL_RIGHT_DIR
	la t1, ball_x_dir
	sw t0, 0(t1)
	jal clear_key_press
	
	la t1, p2_score
	lw t0, 0(t1)
	li t1, GAME_WIN_POINTS
	beq t0, t1, end_game
	
	j new_round

p2_loses_round:
	la t1, p1_score
	lw t0, 0(t1)
	addi t0, t0, 1
	sw t0, 0(t1)
	
	li t0, BALL_LEFT_DIR
	la t1, ball_x_dir
	sw t0, 0(t1)
	jal clear_key_press
		
	la t1, p1_score
	lw t0, 0(t1)
	li t1, GAME_WIN_POINTS
	beq t0, t1, end_game
	
	j new_round

end_game:
	jal clear_board

	la t2, p1_score
	lw t0, 0(t2)
	li t1, GAME_WIN_POINTS
	bne t0, t1, .player_2_wins

.player_1_wins:
	li a0, PLAYER_NUM_WIN_X
	li a1, PLAYER_NUM_WIN_Y
	addi a1, a1, 1
	la t0, color_white
	lw a2, 0(t0)
	jal draw_point
	
	li a0, PLAYER_NUM_WIN_X
	addi a0, a0, 1
	li a1, PLAYER_NUM_WIN_Y
	la t0, color_white
	lw a2, 0(t0)
	li a3, PLAYER_NUM_WIN_Y
	addi a3, a3, PLAYER_NUM_WIN_H
	jal draw_vertical_line
	
	li a0, PLAYER_NUM_WIN_X
	li a1, PLAYER_NUM_WIN_Y
	addi a1, a1, PLAYER_NUM_WIN_H
	la t0, color_white
	lw a2, 0(t0)
	addi a3, a0, 2
	jal draw_horizontal_line
	j .win_p

.player_2_wins:
	li a0, PLAYER_NUM_WIN_X
	li a1, PLAYER_NUM_WIN_Y
	addi a1, a1, 1
	la t0, color_white
	lw a2, 0(t0)
	jal draw_point
	
	li a0, PLAYER_NUM_WIN_X
	addi a0, a0, 1
	li a1, PLAYER_NUM_WIN_Y
	la t0, color_white
	lw a2, 0(t0)
	addi a3, a0, 2
	jal draw_horizontal_line
	
	li a0, PLAYER_NUM_WIN_X
	addi a0, a0, 4
	li a1, PLAYER_NUM_WIN_Y
	addi a1, a1, 1
	la t0, color_white
	lw a2, 0(t0)
	jal draw_point
			
	li a0, PLAYER_NUM_WIN_X
	addi a0, a0, 3
	li a1, PLAYER_NUM_WIN_Y
	addi a1, a1, 2
	la t0, color_white
	lw a2, 0(t0)
	jal draw_point
	
	li a0, PLAYER_NUM_WIN_X
	addi a0, a0, 2
	li a1, PLAYER_NUM_WIN_Y
	addi a1, a1, 3
	la t0, color_white
	lw a2, 0(t0)
	jal draw_point
	
	li a0, PLAYER_NUM_WIN_X
	addi a0, a0, 1
	li a1, PLAYER_NUM_WIN_Y
	addi a1, a1, 4
	la t0, color_white
	lw a2, 0(t0)
	jal draw_point
	
	li a0, PLAYER_NUM_WIN_X
	li a1, PLAYER_NUM_WIN_Y
	addi a1, a1, PLAYER_NUM_WIN_H
	la t0, color_white
	lw a2, 0(t0)
	addi a3, a0, 4
	jal draw_horizontal_line

.win_p:
	li a0, P_CHAR_WIN_X
	li a1, P_CHAR_WIN_Y
	la t0, color_white
	lw a2, 0(t0)
	li a3, P_CHAR_WIN_Y
	addi a3, a3, P_CHAR_WIN_H
	jal draw_vertical_line

	li a0, P_CHAR_WIN_X
	addi a0, a0, 4
	li a1, P_CHAR_WIN_Y
	addi a1, a1, 1
	la t0, color_white
	lw a2, 0(t0)
	addi a3, a1, 2
	jal draw_vertical_line

	li a0, P_CHAR_WIN_X
	addi a0, a0, 1
	li a1, P_CHAR_WIN_Y
	addi a1, a1, 3
	la t0, color_white
	lw a2, 0(t0)
	addi a3, a0, 2
	jal draw_horizontal_line

	li a0, P_CHAR_WIN_X
	addi a0, a0, 1
	li a1, P_CHAR_WIN_Y
	la t0, color_white
	lw a2, 0(t0)
	addi a3, a0, 3
	jal draw_horizontal_line

.wins:
	li a0, WINS_TEXT_X
	li a1, WINS_TEXT_Y
	la t0, color_white
	lw a2, 0(t0)
	addi a3, a1, 2
	jal draw_vertical_line
	
	li a0, WINS_TEXT_X
	addi a0, a0, 1
	li a1, WINS_TEXT_Y
	addi a1, a1, 3
	la t0, color_white
	lw a2, 0(t0)
	addi a3, a1, 1
	jal draw_vertical_line
	
	li a0, WINS_TEXT_X
	addi a0, a0, 2
	li a1, WINS_TEXT_Y
	addi a1, a1, WINS_TEXT_H
	la t0, color_white
	lw a2, 0(t0)
	jal draw_point
	
	li a0, WINS_TEXT_X
	addi a0, a0, 3
	li a1, WINS_TEXT_Y
	addi a1, a1, 3
	la t0, color_white
	lw a2, 0(t0)
	addi a3, a1, 1
	jal draw_vertical_line
	
	li a0, WINS_TEXT_X
	addi a0, a0, 4
	li a1, WINS_TEXT_Y
	addi a1, a1, WINS_TEXT_H
	la t0, color_white
	lw a2, 0(t0)
	jal draw_point
	
	li a0, WINS_TEXT_X
	addi a0, a0, 5
	li a1, WINS_TEXT_Y
	addi a1, a1, 3
	la t0, color_white
	lw a2, 0(t0)
	addi a3, a1, 1
	jal draw_vertical_line
	
	li a0, WINS_TEXT_X
	addi a0, a0, 6
	li a1, WINS_TEXT_Y
	la t0, color_white
	lw a2, 0(t0)
	addi a3, a1, 2
	jal draw_vertical_line

.eqv I_OFFSET, 8
	li a0, WINS_TEXT_X
	addi a0, a0, I_OFFSET
	li a1, WINS_TEXT_Y
	la t0, color_white
	lw a2, 0(t0)
	addi a3, a0, 4 
	jal draw_horizontal_line
	
	li a0, WINS_TEXT_X
	addi a0, a0, I_OFFSET
	addi a0, a0, 2
	li a1, WINS_TEXT_Y
	la t0, color_white
	lw a2, 0(t0)
	addi a3, a1, WINS_TEXT_H
	jal draw_vertical_line
	
	li a0, WINS_TEXT_X
	addi a0, a0, I_OFFSET
	li a1, WINS_TEXT_Y
	addi a1, a1, WINS_TEXT_H
	la t0, color_white
	lw a2, 0(t0)
	addi a3, a0, 4 
	jal draw_horizontal_line

.eqv N_OFFSET, 14
	li a0, WINS_TEXT_X
	addi a0, a0, N_OFFSET
	li a1, WINS_TEXT_Y
	la t0, color_white
	lw a2, 0(t0)
	addi a3, a1, WINS_TEXT_H
	jal draw_vertical_line
	
	li a0, WINS_TEXT_X
	addi a0, a0, N_OFFSET
	addi a0, a0, 1
	li a1, WINS_TEXT_Y
	la t0, color_white
	lw a2, 0(t0)
	addi a3, a1, 1
	jal draw_vertical_line
	
	li a0, WINS_TEXT_X
	addi a0, a0, N_OFFSET
	addi a0, a0, 2
	li a1, WINS_TEXT_Y
	addi a1, a1, 2
	la t0, color_white
	lw a2, 0(t0)
	addi a3, a1, 1
	jal draw_vertical_line
	
	li a0, WINS_TEXT_X
	addi a0, a0, N_OFFSET
	addi a0, a0, 3
	li a1, WINS_TEXT_Y
	addi a1, a1, 4
	la t0, color_white
	lw a2, 0(t0)
	addi a3, a1, 1
	jal draw_vertical_line

	li a0, WINS_TEXT_X
	addi a0, a0, N_OFFSET
	addi a0, a0, 4
	li a1, WINS_TEXT_Y
	la t0, color_white
	lw a2, 0(t0)
	addi a3, a1, WINS_TEXT_H
	jal draw_vertical_line

.eqv S_OFFSET, 20
	li a0, WINS_TEXT_X
	addi a0, a0, S_OFFSET
	li a1, WINS_TEXT_Y
	la t0, color_white
	lw a2, 0(t0)
	addi a3, a0, 4
	jal draw_horizontal_line
	
	li a0, WINS_TEXT_X
	addi a0, a0, S_OFFSET
	li a1, WINS_TEXT_Y
	la t0, color_white
	lw a2, 0(t0)
	addi a3, a1, 1
	jal draw_vertical_line
	
	li a0, WINS_TEXT_X
	addi a0, a0, S_OFFSET
	li a1, WINS_TEXT_Y
	addi a1, a1, 2
	la t0, color_white
	lw a2, 0(t0)
	addi a3, a0, 2
	jal draw_horizontal_line
	
	li a0, WINS_TEXT_X
	addi a0, a0, S_OFFSET
	addi a0, a0, 2
	li a1, WINS_TEXT_Y
	addi a1, a1, 3
	la t0, color_white
	lw a2, 0(t0)
	addi a3, a0, 1
	jal draw_horizontal_line
	
	li a0, WINS_TEXT_X
	addi a0, a0, S_OFFSET
	addi a0, a0, 4
	li a1, WINS_TEXT_Y
	addi a1, a1, 3
	la t0, color_white
	lw a2, 0(t0)
	addi a3, a1, 2
	jal draw_vertical_line
	
	li a0, WINS_TEXT_X
	addi a0, a0, S_OFFSET
	li a1, WINS_TEXT_Y
	addi a1, a1, WINS_TEXT_H
	la t0, color_white
	lw a2, 0(t0)
	addi a3, a0, 4
	jal draw_horizontal_line

.pause:
	li a0, 3000
	li a7, 32
	ecall		

	jal clear_key_press	

.reset_wait:
	li a0, 10
	li a7, 32
	ecall		

	li t2, KEY_STATUS_ADDRESS
	lw t0, 0(t2)
	beqz t0, .reset_wait	

.reset:
	la t1, p1_score
	sw zero, 0(t1)
	la t1, p2_score
	sw zero, 0(t1)
	jal clear_key_press
	jal clear_board
	j new_game

draw_paddle:
	addi sp, sp, -20
	sw ra, 0(sp)
	sw s0, 4(sp)
	sw s1, 8(sp)
	sw s2, 12(sp)
	sw s3, 16(sp)

	mv s0, a0
	mv s1, a1
	mv s2, a2
	mv s3, a3

	li t0, MOV_STAY
	beq t0, s3, .no_mov
	li t0, MOV_DOWN
	beq t0, s3, .down

.up: 
	mv a0, s0
	mv a1, s1 
	addi a1, a1, PADDLE_LENGTH
	la t0, color_black
	lw a2, 0(t0)
	jal draw_point
	
	li t0, TOP_PADDLE_Y_ROW
	beq s1, t0, .no_mov
	addi s1, s1, -1
	j .move
		
.down:
	mv a0, s0
	mv a1, s1
	la t0, color_black
	lw a2, 0(t0)
	jal draw_point
	
	li t0, BOTTOM_PADDLE_Y_ROW
	beq s1, t0, .no_mov
	addi s1, s1, 1
	j .move

.no_mov:
	li s3, MOV_STAY

.move:
	mv a0, s0
	mv a1, s1
	mv a2, s2
	li t0, PADDLE_LENGTH
	add a3, a1, t0
	jal draw_vertical_line

	mv a0, s1
	mv a1, s3

	lw ra, 0(sp)
	lw s0, 4(sp)
	lw s1, 8(sp)
	lw s2, 12(sp)
	lw s3, 16(sp)
	addi sp, sp, 20
	
	jalr zero, ra, 0

draw_score:
    addi sp, sp, -4
    sw ra, 0(sp)

    li a0, P1_SCORE_COLUMN
    li a1, SCORE_Y
    la t0, p1_score
    lw a2, 0(t0)
    la t0, color_white
    lw a3, 0(t0)
    jal draw_digit

    li a0, P2_SCORE_COLUMN
    li a1, SCORE_Y
    la t0, p2_score
    lw a2, 0(t0)
    la t0, color_white
    lw a3, 0(t0)
    jal draw_digit

    li a0, SCORE_DASH_X
    li a1, SCORE_DASH_Y
    la t0, color_white
    lw a2, 0(t0)
    li a3, SCORE_DASH_END_X
    jal draw_horizontal_line

    lw ra, 0(sp)
    addi sp, sp, 4
    jalr zero, ra, 0

draw_digit:
    addi sp, sp, -20
    sw ra,  0(sp)
    sw s8,  4(sp)
    sw s9,  8(sp)
    sw s10, 12(sp)
    sw s11, 16(sp)

    mv s8, a0
    mv s9, a1
    mv s11, a3

    beqz a2, digit_0
    li t0, 1
    beq a2, t0, digit_1
    li t0, 2
    beq a2, t0, digit_2
    li t0, 3
    beq a2, t0, digit_3
    li t0, 4
    beq a2, t0, digit_4
    li t0, 5
    beq a2, t0, digit_5
    li t0, 6
    beq a2, t0, digit_6
    li t0, 7
    beq a2, t0, digit_7
    li t0, 8
    beq a2, t0, digit_8
    li t0, 9
    beq a2, t0, digit_9

    li s10, 0
    j digit_pattern_ready

digit_0:
    li s10, 0x7B6F
    j digit_pattern_ready

digit_1:
    li s10, 0x749A
    j digit_pattern_ready

digit_2:
    li s10, 0x73E7
    j digit_pattern_ready

digit_3:
    li s10, 0x79E7
    j digit_pattern_ready

digit_4:
    li s10, 0x49ED
    j digit_pattern_ready

digit_5:
    li s10, 0x79CF
    j digit_pattern_ready

digit_6:
    li s10, 0x7BCF
    j digit_pattern_ready

digit_7:
    li s10, 0x4927
    j digit_pattern_ready

digit_8:
    li s10, 0x7BEF
    j digit_pattern_ready

digit_9:
    li s10, 0x79EF

digit_pattern_ready:
    li t2, 0
    li t3, 0
    li t4, 0

digit_loop:
    srl t5, s10, t2
    andi t5, t5, 1

    add a0, s8, t3
    add a1, s9, t4

    beqz t5, digit_black
    mv a2, s11
    j digit_write

digit_black:
    la  t6, color_black
    lw  a2, 0(t6)

digit_write:
    jal draw_point

    addi t2, t2, 1
    addi t3, t3, 1
    li t6, 3
    blt t3, t6, digit_continue

    li t3, 0
    addi t4, t4, 1

digit_continue:
    li t6, 15
    blt t2, t6, digit_loop

    lw ra,  0(sp)
    lw s8,  4(sp)
    lw s9,  8(sp)
    lw s10, 12(sp)
    lw s11, 16(sp)
    addi sp, sp, 20
    jalr zero, ra, 0

draw_horizontal_line:
	addi sp, sp, -16
	sw ra, 0(sp)
	sw s0, 4(sp)
	sw s1, 8(sp)
	sw s2, 12(sp)
	
	sub s0, a3, a0
	mv s1, a0
	li s2, 0
	
.horizontal_loop:
	add a0, s1, s0
	jal draw_point
	addi s0, s0, -1
	bge s0, s2, .horizontal_loop
	
	lw ra, 0(sp)
	lw s0, 4(sp)
	lw s1, 8(sp)
	lw s2, 12(sp)
	addi sp, sp, 16	
	jalr zero, ra, 0

draw_title_screen:
	addi sp, sp, -4
	sw ra, 0(sp)

	li a0, 10
	li a1, TITLE_SCREEN_FIRST_LINE_ROW_Y
	la t0, color_red
	lw a2, 0(t0)
	li a3, 53
	jal draw_horizontal_line
	
	li a0, 10
	li a1, TITLE_SCREEN_FIRST_LINE_ROW_Y
	addi a1, a1, 1
	la t0, color_cyan
	lw a2, 0(t0)
	li a3, 53
	jal draw_horizontal_line
	
	li a0, 10
	li a1, TITLE_SCREEN_FIRST_LINE_ROW_Y
	addi a1, a1, 2
	la t0, color_orange
	lw a2, 0(t0)
	li a3, 53
	jal draw_horizontal_line
	
	li a0, 10
	li a1, TITLE_SCREEN_SECOND_LINE_ROW_Y
	la t0, color_red
	lw a2, 0(t0)
	li a3, 53
	jal draw_horizontal_line
	
	li a0, 10
	li a1, TITLE_SCREEN_SECOND_LINE_ROW_Y
	addi a1, a1, 1
	la t0, color_cyan
	lw a2, 0(t0)
	li a3, 53
	jal draw_horizontal_line
	
	li a0, 10
	li a1, TITLE_SCREEN_SECOND_LINE_ROW_Y
	addi a1, a1, 2
	la t0, color_orange
	lw a2, 0(t0)
	li a3, 53
	jal draw_horizontal_line
	
	li a0, PONG_TEXT_X
	li a1, PONG_TEXT_Y
	la t0, color_white
	lw a2, 0(t0)
	li a3, PONG_TEXT_Y
	addi a3, a3, PONG_TEXT_H
	jal draw_vertical_line
	
	li a0, PONG_TEXT_X
	addi a0, a0, 4
	li a1, PONG_TEXT_Y
	addi a1, a1, 1
	la t0, color_white
	lw a2, 0(t0)
	addi a3, a1, 2
	jal draw_vertical_line
	
	li a0, PONG_TEXT_X
	addi a0, a0, 1
	li a1, PONG_TEXT_Y
	addi a1, a1, 3
	la t0, color_white
	lw a2, 0(t0)
	addi a3, a0, 2
	jal draw_horizontal_line
	
	li a0, PONG_TEXT_X
	addi a0, a0, 1
	li a1, PONG_TEXT_Y
	la t0, color_white
	lw a2, 0(t0)
	addi a3, a0, 3
	jal draw_horizontal_line
	
	li a0, PONG_TEXT_X
	addi a0, a0, 6
	li a1, PONG_TEXT_Y
	la t0, color_white
	lw a2, 0(t0)
	li a3, PONG_TEXT_Y
	addi a3, a3, PONG_TEXT_H
	jal draw_vertical_line
	
	li a0, PONG_TEXT_X
	addi a0, a0, 10
	li a1, PONG_TEXT_Y
	la t0, color_white
	lw a2, 0(t0)
	li a3, PONG_TEXT_Y
	addi a3, a3, PONG_TEXT_H
	jal draw_vertical_line
	
	li a0, PONG_TEXT_X
	addi a0, a0, 6
	li a1, PONG_TEXT_Y
	la t0, color_white
	lw a2, 0(t0)
	addi a3, a0, 3
	jal draw_horizontal_line

	li a0, PONG_TEXT_X
	addi a0, a0, 6
	li a1, PONG_TEXT_Y
	addi a1,  a1, 5
	la t0, color_white
	lw a2, 0(t0)
	addi a3, a0, 3
	jal draw_horizontal_line
			
	li a0, PONG_TEXT_X
	addi a0, a0, 12
	li a1, PONG_TEXT_Y
	la t0, color_white
	lw a2, 0(t0)
	li a3, PONG_TEXT_Y
	addi a3, a3, PONG_TEXT_H
	jal draw_vertical_line
	
	li a0, PONG_TEXT_X
	addi a0, a0, 13
	li a1, PONG_TEXT_Y
	la t0, color_white
	lw a2, 0(t0)
	addi a3, a1, 1
	jal draw_vertical_line
	
	li a0, PONG_TEXT_X
	addi a0, a0, 14
	li a1, PONG_TEXT_Y
	addi a1, a1, 2
	la t0, color_white
	lw a2, 0(t0)
	addi a3, a1, 1
	jal draw_vertical_line
	
	li a0, PONG_TEXT_X
	addi a0, a0, 15
	li a1, PONG_TEXT_Y
	addi a1, a1, 4
	la t0, color_white
	lw a2, 0(t0)
	addi a3, a1, 1
	jal draw_vertical_line
	
	li a0, PONG_TEXT_X
	addi a0, a0, 16
	li a1, PONG_TEXT_Y
	la t0, color_white
	lw a2, 0(t0)
	li a3, PONG_TEXT_Y
	addi a3, a3, PONG_TEXT_H
	jal draw_vertical_line
	
	li a0, PONG_TEXT_X
	addi a0, a0, 18
	li a1, PONG_TEXT_Y
	la t0, color_white
	lw a2, 0(t0)
	li a3, PONG_TEXT_Y
	addi a3, a3, PONG_TEXT_H
	jal draw_vertical_line
	
	li a0, PONG_TEXT_X
	addi a0, a0, 19
	li a1, PONG_TEXT_Y
	addi a1, a1, 5
	la t0, color_white
	lw a2, 0(t0)
	addi a3, a0, 3
	jal draw_horizontal_line
	
	li a0, PONG_TEXT_X
	addi a0, a0, 19
	li a1, PONG_TEXT_Y
	la t0, color_white
	lw a2, 0(t0)
	addi a3, a0, 3
	jal draw_horizontal_line
	
	li a0, PONG_TEXT_X
	addi a0, a0, 20
	li a1, PONG_TEXT_Y
	addi a1, a1, 3
	la t0, color_white
	lw a2, 0(t0)
	addi a3, a0, 2
	jal draw_horizontal_line
	
	li a0, PONG_TEXT_X
	addi a0, a0, 22
	li a1, PONG_TEXT_Y
	addi a1, a1, 4
	la t0, color_white
	lw a2, 0(t0)
	jal draw_point
	
	li a0, PRESS_TEXT_X
	li a1, PRESS_TEXT_Y
	la t0, color_white
	lw a2, 0(t0)
	addi a3, a1, PRESS_TEXT_H
	jal draw_vertical_line
	
	li a0, PRESS_TEXT_X
	addi a0, a0, 3
	li a1, PRESS_TEXT_Y
	addi a1, a1, 1
	la t0, color_white
	lw a2, 0(t0)
	addi a3, a1, 1
	jal draw_vertical_line
	
	li a0, PRESS_TEXT_X
	addi a0, a0, 1
	li a1, PRESS_TEXT_Y
	la t0, color_white
	lw a2, 0(t0)
	addi a3, a0, 2
	jal draw_horizontal_line
	
	li a0, PRESS_TEXT_X
	addi a0, a0, 1
	li a1, PRESS_TEXT_Y
	addi a1, a1, 2
	la t0, color_white
	lw a2, 0(t0)
	addi a3, a0, 2
	jal draw_horizontal_line
	
	li a0, PRESS_TEXT_X
	addi a0, a0, 5
	li a1, PRESS_TEXT_Y
	la t0, color_white
	lw a2, 0(t0)
	addi a3, a1, PRESS_TEXT_H
	jal draw_vertical_line
	
	li a0, PRESS_TEXT_X
	addi a0, a0, 7
	li a1, PRESS_TEXT_Y
	la t0, color_white
	lw a2, 0(t0)
	addi a3, a1, PRESS_TEXT_H
	jal draw_vertical_line
	
	li a0, PRESS_TEXT_X
	addi a0, a0, 7
	li a1, PRESS_TEXT_Y
	addi a1, a1, 2
	la t0, color_black
	lw a2, 0(t0)
	jal draw_point
	
	li a0, PRESS_TEXT_X
	addi a0, a0, 6
	li a1, PRESS_TEXT_Y
	la t0, color_white
	lw a2, 0(t0)
	jal draw_point

	li a0, PRESS_TEXT_X
	addi a0, a0, 6
	li a1, PRESS_TEXT_Y
	addi a1, a1, 2
	la t0, color_white
	lw a2, 0(t0)
	jal draw_point
			
	li a0, PRESS_TEXT_X
	addi a0, a0, 9
	li a1, PRESS_TEXT_Y
	la t0, color_white
	lw a2, 0(t0)
	addi a3, a1, PRESS_TEXT_H
	jal draw_vertical_line
	
	li a0, PRESS_TEXT_X
	addi a0, a0, 10
	li a1, PRESS_TEXT_Y
	la t0, color_white
	lw a2, 0(t0)
	jal draw_point
	
	li a0, PRESS_TEXT_X
	addi a0, a0, 10
	li a1, PRESS_TEXT_Y
	addi a1, a1, 2
	la t0, color_white
	lw a2, 0(t0)
	jal draw_point
	
	li a0, PRESS_TEXT_X
	addi a0, a0, 10
	li a1, PRESS_TEXT_Y
	addi a1, a1, 4
	la t0, color_white
	lw a2, 0(t0)
	jal draw_point
	
	li a0, PRESS_TEXT_X
	addi a0, a0, 12
	li a1, PRESS_TEXT_Y
	la t0, color_white
	lw a2, 0(t0)
	addi a3, a1, PRESS_TEXT_H
	jal draw_vertical_line
	
	li a0, PRESS_TEXT_X
	addi a0, a0, 12
	li a1, PRESS_TEXT_Y
	addi a1, a1, 3
	la t0, color_black
	lw a2, 0(t0)
	jal draw_point
	
	li a0, PRESS_TEXT_X
	addi a0, a0, 13
	li a1, PRESS_TEXT_Y
	la t0, color_white
	lw a2, 0(t0)
	jal draw_point
	
	li a0, PRESS_TEXT_X
	addi a0, a0, 13
	li a1, PRESS_TEXT_Y
	addi a1,  a1, 2
	la t0, color_white
	lw a2, 0(t0)
	jal draw_point

	li a0, PRESS_TEXT_X
	addi a0, a0, 13
	li a1, PRESS_TEXT_Y
	addi a1,  a1, 4
	la t0, color_white
	lw a2, 0(t0)
	jal draw_point
	
	li a0, PRESS_TEXT_X
	addi a0, a0, 14
	li a1, PRESS_TEXT_Y
	la t0, color_white
	lw a2, 0(t0)
	addi a3, a1, PRESS_TEXT_H
	jal draw_vertical_line

	li a0, PRESS_TEXT_X
	addi a0, a0, 14
	li a1, PRESS_TEXT_Y
	addi a1,  a1, 1
	la t0, color_black
	lw a2, 0(t0)
	jal draw_point

	li a0, PRESS_TEXT_X
	addi a0, a0, 16
	li a1, PRESS_TEXT_Y
	la t0, color_white
	lw a2, 0(t0)
	addi a3, a1, PRESS_TEXT_H
	jal draw_vertical_line
	
	li a0, PRESS_TEXT_X
	addi a0, a0, 16
	li a1, PRESS_TEXT_Y
	addi a1, a1, 3
	la t0, color_black
	lw a2, 0(t0)
	jal draw_point
	
	li a0, PRESS_TEXT_X
	addi a0, a0, 17
	li a1, PRESS_TEXT_Y
	la t0, color_white
	lw a2, 0(t0)
	jal draw_point
	
	li a0, PRESS_TEXT_X
	addi a0, a0, 17
	li a1, PRESS_TEXT_Y
	addi a1,  a1, 2
	la t0, color_white
	lw a2, 0(t0)
	jal draw_point

	li a0, PRESS_TEXT_X
	addi a0, a0, 17
	li a1, PRESS_TEXT_Y
	addi a1,  a1, 4
	la t0, color_white
	lw a2, 0(t0)
	jal draw_point
	
	li a0, PRESS_TEXT_X
	addi a0, a0, 18
	li a1, PRESS_TEXT_Y
	la t0, color_white
	lw a2, 0(t0)
	addi a3, a1, PRESS_TEXT_H
	jal draw_vertical_line

	li a0, PRESS_TEXT_X
	addi a0, a0, 18
	li a1, PRESS_TEXT_Y
	addi a1,  a1, 1
	la t0, color_black
	lw a2, 0(t0)
	jal draw_point
	
	li a0, PRESS_TEXT_X
	addi a0, a0, 23
	li a1, PRESS_TEXT_Y
	la t0, color_white
	lw a2, 0(t0)
	addi a3, a1, PRESS_TEXT_H
	jal draw_vertical_line
			
	li a0, PRESS_TEXT_X
	addi a0, a0, 22
	li a1, PRESS_TEXT_Y
	addi a1,  a1, 1
	la t0, color_white
	lw a2, 0(t0)
	jal draw_point
	
	li a0, PRESS_TEXT_X
	addi a0, a0, 22
	li a1, PRESS_TEXT_Y
	addi a1, a1, PRESS_TEXT_H
	la t0, color_white
	lw a2, 0(t0)
	addi a3, a0, 2
	jal draw_horizontal_line
	
	lw ra, 0(sp)
	addi sp, sp, 4
	jalr zero, ra, 0
	
clear_key_press:
	li t1, KEY_INPUT_ADDRESS
	lw t0, 0(t1)
	jalr zero, ra, 0

clear_board:
	mv t0, gp                   
	li t1, TOTAL_PIXEL          
	add t2, t0, t1              
	la t4, color_black          
	lw t3, 0(t4)

.clear_loop:
	sw t3, 0(t0)                
	addi t0, t0, 4              
	blt t0, t2, .clear_loop     
	jalr zero, ra, 0

draw_vertical_line:
	addi sp, sp, -12            
	sw ra, 0(sp)
	sw a1, 4(sp)
	sw s0, 8(sp)

	sub s0, a3, a1              

.vertical_loop:
	jal draw_point              
	addi a1, a1, 1              
	addi s0, s0, -1             
	bgez s0, .vertical_loop     

	lw ra, 0(sp)                
	lw a1, 4(sp)
	lw s0, 8(sp)
	addi sp, sp, 12
	jalr zero, ra, 0

draw_point:
	bltz a0, .draw_point_end
	bltz a1, .draw_point_end
	li t0, SCREEN_WIDTH
	bge a0, t0, .draw_point_end
	li t0, SCREEN_HEIGHT
	bge a1, t0, .draw_point_end

	slli t0, a1, 6          # t0 = y * 64
	add t0, t0, a0          # t0 = y * 64 + x
	slli t0, t0, 2          # t0 = (y * 64 + x) * 4
	add t0, t0, gp          # t0 = direccion del pixel
	sw a2, 0(t0)

.draw_point_end:
	jalr zero, ra, 0
	
