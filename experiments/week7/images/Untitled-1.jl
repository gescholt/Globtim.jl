
using Groebner

sys = Groebner.Examples.cyclicn(7)
@profview groebner(sys)

