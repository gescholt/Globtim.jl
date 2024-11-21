function define_lotka_volterra_model()
    @independent_variables t
    @variables x1(t) x2(t) y1(t)
    @parameters a b c
    D = Differential(t)
    params = [a, b, c]
    states = [x1, x2]
    @named model = ODESystem(
        [D(x1) ~ a * x1 + b * x1 * x2,
         D(x2) ~ b * x1 * x2 + c * x2], 
        t, states, params)
    outputs = [y1 ~ x1]
    return model, params, states, outputs
end