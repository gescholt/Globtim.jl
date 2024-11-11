using Globtim 
using DynamicPolynomials

"This seems promising, we switch to BigInt when overflow occurs".

@polyvar x[1:4]
for n in 20:33
    @time begin
        Pn = symbolic_legendre(n)
    end
    println("P_$n = $Pn")
end