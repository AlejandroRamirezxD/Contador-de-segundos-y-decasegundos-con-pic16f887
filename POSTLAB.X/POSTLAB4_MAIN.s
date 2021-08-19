
 ; Archivo    :	  PRELAB4_MAIN.s  
 ; Dispositivo:	  PIC16F887
 ; Autor      :	  Alejandro Ramírez
 ; Compilador :	  MPLAB V5.4
 ; Programa   :	  Contador de 4 bits, que incrementan con interruptores 
 ;		  con pull ups internos.
 ; Hardware   :	  4 leds en porta y 2 push en portb, un 7-SEG en port c y d
 ; 
 
 ; Última modificación: 19 AGOSTO, 2021
  
 PROCESSOR 16F887
 #include <xc.inc>
 
 ; Configuración de pines
 CONFIG FOSC=INTRC_NOCLKOUT	// Oscillador Interno sin salidas  
 CONFIG WDTE=OFF    // WDT disabled 
 CONFIG PWRTE=OFF    // PWRT enabled 
 CONFIG MCLRE=OFF   // El pin de MCLR se utiliza como I/O
 CONFIG CP=OFF	    // Sin protección de código
 CONFIG CPD=OFF	    // Sin protección de datos

 CONFIG BOREN=OFF   // Sin reinicio cuando el voltaje de alimentación baja de 4V
 CONFIG IESO=OFF    // Reinicio sin cambio de reloj de interno a externo
 CONFIG FCMEN=OFF   // Cambio de reloj externo a interno en caso de fallo
 CONFIG LVP=OFF	    // programación en bajo voltaje permitida
 
 ;configuration word 2
 CONFIG WRT=OFF	    // Protección de autoescritura por el programa desactivada
 CONFIG BOR4V=BOR40V// Reinicio abajo de 4V, (BOR21V=2.1V)

/*
+--------------------------------------------------------------------------+
|                               MACROS                                     |
+--------------------------------------------------------------------------+ 
*/  
 restart_tmr0 macro 
    banksel PORTA   ; ciclo de 0.02s 
    movlw   251	    ; N = 12   -   t_deseado = (4*t_osc)(256-TMR0)(PRESCARLER)
    movwf   TMR0    ; Ciclo de 1000ms
    bcf	    T0IF    ; Bandera de overflow de tmr0, del INTCON BIT 2
    endm 
 
/*
+--------------------------------------------------------------------------+
|                              VARIABLES                                   |
+--------------------------------------------------------------------------+ 
*/   
 UP	EQU 0
 DOWN	EQU 7
  
 PSECT udata_bank0	; Memoria comun 
    cont:		DS 2	; 2 byte
    cont_S:		DS 1	; 1 byte
    cont_D:		DS 1	; 1 byte
        
 PSECT udata_shr	; Memoria comun 
    W_TEMP:		DS  1	; 1 byte
    STATUS_TEMP:	DS  1	; 1 byte
           
/*
+--------------------------------------------------------------------------+
|                              VECTOR RESET                                |
+--------------------------------------------------------------------------+ 
*/   
 PSECT resVect, class=CODE, abs, delta=2
 ORG 00h	;posición 0000h para el reset
 resetVec:
     PAGESEL main
     goto main

/*
+--------------------------------------------------------------------------+
|                   POSICION PARA LAS INTERRUPCIONES                       |
+--------------------------------------------------------------------------+ 
*/

PSECT resVect, class=CODE, abs, delta=2  
ORG 04h	; Posicion 0004h para las interrupciones
 
 push:
    movwf   W_TEMP	; Pasar el valor de W a la variable W_Temporal
    swapf   STATUS, W	; No se tocan las banderas, pero se hace un swap
    movwf   STATUS_TEMP

 isr:
    btfsc   RBIF	; Bandera del PORTB B
    call    int_iocb	; Subrutina para incrementar el puerto A 
    
    btfsc   T0IF	; Bandera del TMR0
    call    int_t0	; Subrutina para el tiempo de 1s
    
 pop:
    swapf   STATUS_TEMP,w
    movwf   STATUS
    swapf   W_TEMP, F
    swapf   W_TEMP, W
    retfie  ; Regreso de int

/*
+--------------------------------------------------------------------------+
|                       SUBRUTINAS DE INTERRUPCIÓN                         |
+--------------------------------------------------------------------------+ 
*/
 int_iocb:
    banksel PORTB	; Registro del PORTB
    
    btfss   PORTB, UP	; Si el UP está presionado sigue la linea
    incf    PORTA
    
    btfsc   PORTA, 4	; Limita el PORTA 
    clrf    PORTA
    
    btfss   PORTB, DOWN ; Si el DOWN está presionado sigue la linea
    decf    PORTA
    
    btfsc   PORTA, 4	; Limita el PORTA 
    call    Maximo_Val_A   
    
    bcf	    RBIF	; Borrar la bandera
    
    return
    
 int_t0: 
    restart_tmr0	 ; 20 ms
    incf    cont
    movf    cont, W
    sublw   50		 ; Se repite 50 veces 
    btfss   STATUS, 2    ; STATUS, 2
    goto    return_t0	 
    clrf    cont    
    incf    cont_S
    return
  
 return_t0:
    return
     
/*
+--------------------------------------------------------------------------+
|                           POSICION DEL CÓDIGO                            |
+--------------------------------------------------------------------------+ 
*/    
PSECT code, delta=2, abs
ORG 100h	; posición para el código
 
/*
+--------------------------------------------------------------------------+
|                                TABLAS                                    |
+--------------------------------------------------------------------------+ 
*/    
 
tabla:
    clrf    PCLATH
    bsf	    PCLATH, 0   ; PCLATH =  01 
    andlw   0x0f	; Pasa números debajo d f
    addwf   PCL		; PC = PCLATH + P CL
			; return que devuelve literal
    retlw   00111111B	;   0	
    retlw   00000110B	;   1
    retlw   01011011B	;   2
    retlw   01001111B	;   3
    retlw   01100110B	;   4
    retlw   01101101B	;   5
    retlw   01111101B	;   6
    retlw   00000111B	;   7
    retlw   01111111B	;   8
    retlw   01101111B	;   9
    retlw   00111111B	;   0
 
/*
+--------------------------------------------------------------------------+
|                            CONFIGURACIÓN                                 |
+--------------------------------------------------------------------------+ 
*/ 
main:
    call    config_io		; Porta out, RB7 y RB0 como input
    call    config_reloj        ; 250 kHz
    call    config_tmr0		; 1:256
    call    config_iocrb	; Interrupcion de push 
    call    config_int_enable	; Interrupciones de TMR0
    banksel PORTA
 
/*
+--------------------------------------------------------------------------+
|                                LOOP                                      |
+--------------------------------------------------------------------------+ 
*/    
loop:
    call displayD   ; Conteo de Displays
    goto loop

/*
+--------------------------------------------------------------------------+
|                          SUB RUTINAS                                     |
+--------------------------------------------------------------------------+ 
*/
displayS:
    movf    cont_S, W
    call    tabla	; Busca el valor de la tabla
    movwf   PORTD	; Pasa el valor de w a portd
    call maxValDisplayS ; Limitar los segundos en el display
    return
     
maxValDisplayS:
    movf    cont_S, W
    sublw   10		; Resetear el conteo a 10 s
    btfss   STATUS,2	; Bandera, de la resta
    goto    $+3		;
    incf    cont_D	; Variable de auxiliar del display de decenas
    clrf    cont_S	; Variable de auxiliar del display de segundos
    return 
    
displayD:
    call    displayS	
    movf    cont_D, w	;
    call    tabla	; Busca el valor de la tabla
    movwf   PORTC	; Pasa el valor de w a portd
    call maxValDisplayD ; Limitar las decenas en el display 
    return

maxValDisplayD:
    movf    cont_D, W	
    sublw   6		; Resetear el conteo a 6 ds
    btfss   STATUS,2	; Bandera, de la resta
    goto    $+2
    clrf    cont_D	; Limpiar PORTD
    return   
   

Maximo_Val_A:
    clrf    PORTA	    ; Limpiar PortA
    bsf	    PORTA, 0	    ; 0001
    bsf	    PORTA, 1	    ; 0011
    bsf	    PORTA, 2	    ; 0111
    bsf	    PORTA, 3	    ; 1111
    return  
    
config_iocrb:
    banksel TRISA
    bsf	    IOCB, UP
    bsf	    IOCB, DOWN
    
    banksel PORTA
    movf    PORTB, W ; Al leer termina condicion de mismatch 
    bcf	    RBIF 
      
    return

config_io:
    banksel ANSEL	; Abrir los bancos de ANSEL y ANSELH   
    clrf    ANSEL	; P.Digitales
    clrf    ANSELH
    
    banksel TRISA	    ; Abrir el banco donde se encuentra TRISA
    clrf    TRISA	    ; port A - salida
    clrf    TRISC	    ; port C - salida
    clrf    TRISD   
    
    bsf	    TRISB, UP	    ; UP Y DOWN COMO ENTRADAS
    bsf	    TRISB, DOWN 
    
    bcf	    OPTION_REG, 7 ;Habilitar pull Ups
    bsf	    WPUB, UP
    bsf	    WPUB, DOWN
       
    banksel PORTA	; Abrir el banco de PORTA
    clrf    PORTA	; Limpiar el valor de PORTA
    clrf    PORTC	; Limpiar el valor de PORTC
    clrf    PORTD
    
    return

config_reloj:		    ; 250 kHz
    banksel OSCCON
    bcf	    IRCF2	    ; OSCCON, 6
    bsf	    IRCF1	    ; OSCCON, 5
    bcf	    IRCF0	    ; OSCCON, 4
    bsf	    SCS		    
    return
    
config_tmr0:
    banksel TRISA   ; Abrir el OPTION_REG del banco donde se encuentra TRISA
    bcf	    T0CS    ; RELOJ INTERNO
    bcf	    PSA	    ; Prescaler
    bsf	    PS2
    bsf	    PS1
    bsf	    PS0	    ; PS = 111 = 1:256
    
    restart_tmr0
    return

config_int_enable:  ; Configurar interrupción del tmr0
    bsf	    GIE	    ; INTON
    bsf	    RBIE
    bcf	    RBIF
    bsf	    T0IE
    bcf	    T0IF
    return
    
 END
 
 



