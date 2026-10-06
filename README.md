# 6502 EMUL

This is an exercice in zig programming, looking how to implement
a simple 6503 emulator, just for fun.
It is not expected to fulfill any practical use whatsoever.

This project is distributed under the MIT license.


## Opcodes

Currently, the following opcodes are implemented and their tests are available:

    ADC
    AND
    ASL
    BCC
    BCS
    BEQ
    BIT
    BMI
    BNE
    BPL
    BVC
    BVS
    CLC
    CLD
    CLI
    CLV
    CMP
    DEC
    DEX
    DEY
    INC
    INX
    INY
    JMP (without indirect adressing)
    JSR
    LDA
    LSR
    NOP
    PHA
    PHP
    PLA
    PLP
    RTS
    SBC
    SEC
    SED
    STA
    TAX
    TAY
    TSX
    TXA
    TXS
    TYA
