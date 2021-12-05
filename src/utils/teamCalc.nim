
proc oscillate*(num: int):int =
    ## Add 1 to even numbers
    ## Remove 1 to odd numbers
    if (num mod 2 == 0):
        return num - 1 # team A
    else:
        return num + 1 # team B
