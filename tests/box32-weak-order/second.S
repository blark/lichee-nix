.text
.weak foo
.type foo,@function
foo:
 mov $22,%eax
 ret
.size foo,.-foo
.section .note.GNU-stack,"",@progbits
