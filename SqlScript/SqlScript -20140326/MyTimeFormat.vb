Public Function MyTimeFormat(ByVal seconds As Integer) As String
    Dim hour As Integer
    Dim min As Integer
    Dim sec As Integer
    Dim duration As String

    'The \ Operator (Visual Basic) returns the integer quotient of a division. For example, the expression 14 \ 4 evaluates to 3.
    'The / Operator (Visual Basic) returns the full quotient, including the remainder, as a floating-point number. For example, the expression 14 / 4 evaluates to 3.5.
    hour = seconds \ 3600
    min = (seconds Mod 3600) \ 60
    sec = seconds Mod 60

    duration = Format(hour, "00") & ":" & Format(min, "00") & ":" & Format(sec, "00")
    Return duration
End Function