function NMFmultiplicative(X::Array, k::Int; quiet::Bool=true, tol::Float64=1e-19, maxiter::Int=1000000, stopconv::Int=10000, initW::Matrix{Float64}=Array{Float64}(0, 0), initH::Matrix{Float64}=Array{Float64}(0, 0), seed::Int=-1, movie::Bool=false, moviename::String="", movieorder=1:k)
	if minimum(X) < 0
		error("All matrix entries must be nonnegative")
	end
	if minimum(sum(X, 2)) == 0
		error("All matrix entries in a row can be 0!")
	end

	if seed >= 0
		srand(seed)
	end

	n, m = size(X)

	consold = falses(m, m)
	inc = 0

	if sizeof(initW) == 0
		W = rand(n, k)
	else
		W = initW
	end
	if sizeof(initH) == 0
		H = rand(k, m)
	else
		H = initH
	end

	if movie
		Xe = W * H
		frame = 1
		NMFk.plotnmf(Xe, W[:,movieorder], H[movieorder,:]; movie=movie, filename=moviename, frame=frame)
	end

	# maxinc = 0
	index = Array(Int, m)
	for i=1:maxiter
		# X1 = repmat(sum(W, 1)', 1, m)
		H = H .* (W' * (X ./ (W * H))) ./ sum(W, 1)'
		# X2 = repmat(sum(H, 2)', n, 1)
		W = W .* ((X ./ (W * H)) * H') ./ sum(H, 2)'
		if movie
			frame += 1
			Xe = W * H
			NMFk.plotnmf(Xe, W[:,movieorder], H[movieorder,:]; movie=movie, filename=moviename, frame=frame)
		end
		if mod(i, 10) == 0
			objvalue = sum((X - W * H).^2) # Frobenius norm is sum((X - W * H).^2)^(1/2) but why bother
			if objvalue < tol
				!quiet && println("Converged by tolerance: number of iterations $(i) $(objvalue)")
				break
			end
			H = max(H, eps())
			W = max(W, eps())
			for q = 1:m
				index[q] = indmax(H[:, q])
			end
			# sum(map(i->sum(index.==i).^2, 1:3))
			cons = repmat(index, 1, m) .== repmat(index', m, 1)
			consdiff = sum(cons .!= consold)
			if consdiff == 0
				inc += 1
			else
				inc = 0
			end
			#if inc > maxinc
			#	maxinc = inc
			#end
			# @printf("\t%d\t%d\t%d\n", i, inc, consdiff)
			if inc > stopconv # this criteria is almost never achieved
				!quiet && println("Converged by consistency: number of iterations $(i) $(inc) $(objvalue)")
				break
			end
			consold = cons
		end
	end
	objvalue = sum((X - W * H).^2)
	return W, H, objvalue
end
