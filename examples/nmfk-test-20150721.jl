testproblem = "20150721"
WellsD = [
"E1"=>(498900,539000)
]
WellsQ = [
"E1"=>[0 100; 100 0]
]
Points = [
"R1"=>(498900,539010),
"R2"=>(498900,539050),
"R3"=>(498900,539100),
"R4"=>(498900,539200),
"R5"=>(498900,539500),
"R6"=>(498900,540000),
"R7"=>(498900,542000),
"R8"=>(498900,545000)
]
time = 0:1:300 # days; two years in total
T = 100 # m2/d
S = 1e-3 # -
nk = 2