import DelimitedFiles
import PlotlyJS

"""
cutoff::Number = .9, cutoff_s::Number = 0.95
"""
function clusterresults(nkrange, W, H, robustness, locations, attributes; clusterattributes::Bool=true, loadassignements::Bool=true, sizeW::Integer=0, lon=nothing, lat=nothing, cutoff::Number=0, cutoff_s::Number=0, figuredir::AbstractString=".", resultdir::AbstractString=".", casefilenameW::AbstractString="attributes", casefilenameH::AbstractString="locations", locationtypes=[], attributetypes=[], locationcolors=NMFk.colors, attributecolors=NMFk.colors, background_color="black", plotlabelH::Bool=true, plotlabelW::Bool=true, biplotlabel::Symbol=:W)
	if length(locationtypes) > 0
		if locationcolors == NMFk.colors
			locationcolors = Vector{String}(undef, length(locationtypes))
			for (j, t) in enumerate(unique(locationtypes))
				locationcolors[locationtypes .== t] .= NMFk.colors[j]
			end
		end
		locationnametype = locations .* " " .* String.(locationtypes)
	else
		locationnametype = locations
	end
	if length(attributetypes) > 0
		if attributecolors == NMFk.colors
			attributecolors = Vector{String}(undef, length(attributetypes))
			for (j, t) in enumerate(unique(attributetypes))
				attributecolor[attributetype .== t] .= NMFk.colors[j]
			end
		end
		attributenametype = attributes .* " " .* String.(attributetypes)
	end
	for k = NMFk.getks(nkrange, robustness[nkrange])
		@assert length(locations) == size(H[k], 2)
		@assert length(attributes) == size(W[k], 1)
		@info("Number of signals: $k")

		@info("$(uppercasefirst(casefilenameH)) (signals=$k)")
		recursivemkdir(resultdir; filename=false)
		DelimitedFiles.writedlm("$resultdir/Hmatrix-$(k).csv", H[k], ',')
		if cutoff > 0
			ia = (H[k] ./ maximum(H[k]; dims=2)) .> cutoff
			for i in 1:k
				@info "Signal $i (max-normalized elements > $cutoff)"
				display(locations[ia[i,:]])
			end
		end
		c = NMFk.labelassignements(NMFk.robustkmeans(H[k], k; resultdir=resultdir, casefilename="Hmatrix", load=loadassignements, save=true)[1].assignments)
		cs = sortperm(c)
		clusterlabels = sort(unique(c))
		signalmap = NMFk.getsignalassignments(H[k], c; clusterlabels=clusterlabels, dims=2)
		clustermap = Vector{Char}(undef, k)
		clustermap .= ' '
		io = open("$resultdir/$(casefilenameH)-groups-$(k).txt", "w")
		for (j, i) in enumerate(clusterlabels)
			@info "Signal $i (S$(signalmap[j])) (k-means clustering)"
			write(io, "Signal $i (S$(signalmap[j])) (k-means clustering)\n")
			display(locations[indexin(c, [i]) .== true])
			for l in locations[indexin(c, [i]) .== true]
				write(io, l)
				write(io, '\n')
			end
			write(io, '\n')
			clustermap[signalmap[j]] = i
		end
		close(io)
		is = signalmap
		@assert is == sortperm(clustermap)
		NMFk.plotmatrix(permutedims(H[k] ./ maximum(H[k]; dims=2)); filename="$figuredir/$(casefilenameH)-$(k).png", xticks=["S$i" for i=1:k], yticks=["$(locations[i]) $(c[i])" for i=1:length(c)], colorkey=false)
		NMFk.plotmatrix((permutedims(H[k] ./ maximum(H[k]; dims=2)))[cs,is]; filename="$figuredir/$(casefilenameH)-sorted-$(k).png", xticks=clustermap[is], yticks=["$(locations[cs][i]) $(c[cs][i])" for i=1:length(c)], colorkey=false, quiet=false)
		NMFk.plotmatrix(permutedims((H[k] ./ sum(H[k]; dims=2)))[cs,is]; filename="$figuredir/$(casefilenameH)-sorted-sumrows-$(k).png", xticks=clustermap[is], yticks=["$(locationnametype[cs][i]) $(c[cs][i])" for i=1:length(c)], colorkey=false)
		NMFk.biplots(permutedims(H[k])[cs,is] ./ maximum(H[k]), locations[cs], clustermap[is]; filename="$figuredir/$(casefilenameH)-biplots-$(k).pdf", background_color=background_color, types=c[cs], plotlabel=plotlabelH)
		length(locationtypes) > 0 && NMFk.biplots(permutedims(H[k])[cs,is]./ maximum(H[k]), locations[cs], clustermap[is]; filename="$figuredir/$(casefilenameH)-biplots-type-$(k).pdf", background_color=background_color, colors=locationcolors[cs], plotlabel=plotlabelH)
		if lon != nothing && lat != nothing
			p = PlotlyJS.plot(NMFk.plot_wells(lon, lat, c), Plotly.Layout(title="Clusters: $k"))
			PlotlyJS.savehtml(p, "$figuredir/clusters-$(k).html", :remote)
			lonlat= [lon lat]
		end
		if lon != nothing && lat != nothing
			DelimitedFiles.writedlm("$resultdir/$(casefilenameH)-$(k).csv", [locations lonlat permutedims(H[k] ./ maximum(H[k]; dims=2)) c], ',')
		else
			DelimitedFiles.writedlm("$resultdir/$(casefilenameH)-$(k).csv", [locations permutedims(H[k] ./ maximum(H[k]; dims=2)) c], ',')
		end
		if clusterattributes
			Wa = W[k]
			if sizeW > 1
				na = convert(Int64, size(W[k], 1) / sizeW)
				Wa = Matrix{typeof(W[k][1,1])}(undef, na, size(W[k], 2))
				i1 = 1
				i2 = sizeW
				for i = 1:na
					Wa[i,:] = sum(W[k][i1:i2,:]; dims=1)
					i1 += sizeW
					i2 += sizeW
 				end
			end
			@info("$(uppercasefirst(casefilenameW)) (signals=$k)")
			DelimitedFiles.writedlm("$resultdir/Wmatrix-$(k).csv", Wa, ',')
			if cutoff > 0
				ia = (Wa ./ maximum(Wa; dims=1)) .> cutoff
				for i in 1:k
					@info "Signal $i (max-normalized elements > $cutoff)"
					display(attributes[ia[:,i]])
				end
			end
			c = NMFk.labelassignements(NMFk.robustkmeans(permutedims(Wa), k; resultdir=resultdir, casefilename="Wmatrix", load=loadassignements, save=true)[1].assignments)
			@assert clusterlabels == sort(unique(c))
			signalmap = NMFk.getsignalassignments(Wa[:,is], c; clusterlabels=clusterlabels, dims=1)
			cassgined = zeros(Int64, length(attributes))
			cnew = Vector{typeof(c[1])}(undef, length(c))
			cnew .= ' '
			snew = Vector{String}(undef, length(c))
			for (j, i) in enumerate(clusterlabels)
				iclustermap = signalmap[j]
				cnew[c .== i] .= clusterlabels[iclustermap]
				snew[c .== i] .= "S$(signalmap[j])"
				# @info "Signal $i -> S$(signalmap[j]) -> $(clusterlabels[signalmap[j]]) (k-means clustering)"
				imt = indexin(c, [i]) .== true
				cassgined[imt] .+= 1
				display(attributes[imt])
			end
			cs = sortperm(cnew)
			if any(cassgined .== 0)
				@warn "$(uppercasefirst(casefilenameW)) not assigned to any cluster:"
				display(attributes[cassgined .== 0])
			end
			if any(cassgined .> 1)
				@warn "$(uppercasefirst(casefilenameW)) assigned to more than luster:"
				display([attributes[cassgined .> 1] cassgined[cassgined .> 1]])
			end
			io = open("$resultdir/$(casefilenameW)-groups-$(k).txt", "w")
			for i in clusterlabels
				@info "Signal $i (k-means clustering; remapped)"
				write(io, "Signal $i (k-means clustering; remapped)\n")
				display(attributes[indexin(cnew, [i]) .== true])
				for a in attributes[indexin(cnew, [i]) .== true]
					write(io, a)
					write(io, '\n')
				end
				write(io, '\n')
			end
			close(io)
			NMFk.plotmatrix(Wa ./ maximum(Wa); filename="$figuredir/$(casefilenameW)-$(k).png", xticks=["S$i" for i=1:k], yticks=["$(attributes[i]) $(c[i])" for i=1:length(c)], colorkey=false)
			ws = sortperm(vec(sum(Wa; dims=1)); rev=true)
			# snew2 = copy(snew)
			# for i = 1:k
			# 	snew2[snew .== "S$(i)"] .= "S$(ws[i])"
			# end
			NMFk.plotmatrix((Wa ./ maximum(Wa; dims=1))[:,ws]; filename="$figuredir/$(casefilenameW)-signals-$(k).png", xticks=["S$i" for i=1:k], yticks=["$(attributes[i])" for i=1:length(c)], colorkey=false)
			NMFk.plotmatrix((Wa ./ maximum(Wa; dims=1))[cs,is]; filename="$figuredir/$(casefilenameW)-sorted-$(k).png", xticks=clustermap[is], yticks=["$(attributes[cs][i]) $(cnew[cs][i])" for i=1:length(c)], colorkey=false, quiet=false)
			# NMFk.plotmatrix(Wa./sum(Wa; dims=1); filename="$figuredir/$(casefilenameW)-sum-$(k).png", xticks=["S$i" for i=1:k], yticks=["$(attributes[i]) $(c[i])" for i=1:length(cols)], colorkey=false)
			# NMFk.plotmatrix((Wa./sum(Wa; dims=1))[cs,:]; filename="$figuredir/$(casefilenameW)-sum2-$(k).png", xticks=["S$i" for i=1:k], yticks=["$(attributes[cs][i]) $(c[cs][i])" for i=1:length(cols)], colorkey=false)
			NMFk.plotmatrix((Wa ./ sum(Wa; dims=1))[cs,is]; filename="$figuredir/$(casefilenameW)-sorted-sumrows-$(k).png", xticks=clustermap[is], yticks=["$(attributes[cs][i]) $(cnew[cs][i])" for i=1:length(c)], colorkey=false)
			NMFk.biplots(Wa[cs,is] ./ maximum(Wa), attributes[cs], clustermap[is]; filename="$figuredir/$(casefilenameW)-biplots-$(k).pdf", background_color=background_color, types=cnew[cs], plotlabel=plotlabelW)
			length(attributetypes) > 0 && NMFk.biplots(Wa[cs,is] ./ maximum(Wa), attributes[cs], clustermap[is]; filename="$figuredir/$(casefilenameW)-biplots-type-$(k).pdf", background_color=background_color, colors=attributecolors[cs], plotlabel=plotlabelW)
			DelimitedFiles.writedlm("$resultdir/$(casefilenameW)-$(k).csv", [attributes (Wa ./ maximum(Wa; dims=1))	 c], ',')

			if biplotlabel == :W
				biplotlabels = [attributes; fill("", length(locations))]
			elseif biplotlabel == :WH
				biplotlabels = [attributes; locations]
			else
				biplotlabels = [fill("", length(attributes)); locations]
			end
			NMFk.biplots([Wa ./ maximum(Wa); permutedims(H[k] ./ maximum(H[k]))], biplotlabels, collect(1:k); filename="$figuredir/all-biplots-$(k).pdf", background_color=background_color, colors=[fill("gray", length(attributes)); locationcolors], plotlabel=plotlabelW)
			NMFk.biplots([(Wa ./ maximum(Wa))[:,is]; permutedims(H[k] ./ maximum(H[k]))[:,is]], biplotlabels, clustermap[is]; filename="$figuredir/all-biplots-sorted-$(k).pdf", background_color=background_color, colors=[fill("gray", length(attributes)); locationcolors], plotlabel=plotlabelW)
		end

		if cutoff_s > 0
			attributesl = sizeW > 1 ? repeat(attributes; inner=sizeW) : attributes
			Xe = W[k] * H[k]
			local table = locations
			local table2 = locations
			local table3 = locations
			for i = 1:k
				Xek = (W[k][:,i:i] * H[k][i:i,:]) ./ Xe
				Xekm = Xek .> cutoff_s
				o = findmax(Xek; dims=1)
				table = hcat(table, map(i->attributesl[i], map(i->o[2][i][1], 1:length(locations))))
				table2 = hcat(table2, map(i->attributesl[Xekm[:,i]], 1:length(locations)))
				table3 = hcat(table3, map(i->sum(Xekm[:,i]), 1:length(locations)))
			end
			if lon != nothing && lat != nothing
				DelimitedFiles.writedlm("$resultdir/$(casefilenameW)-$(k)-table_max.csv", [lonlat table], ',')
				DelimitedFiles.writedlm("$resultdir/$(casefilenameW)-$(k)-table_$(cutoff_s).csv", [lonlat table2], ';')
				DelimitedFiles.writedlm("$resultdir/$(casefilenameW)-$(k)-table_count_$(cutoff_s).csv", [lonlat table3], ',')
			else
				DelimitedFiles.writedlm("$resultdir/$(casefilenameW)-$(k)-table_max.csv", table, ',')
				DelimitedFiles.writedlm("$resultdir/$(casefilenameW)-$(k)-table_$(cutoff_s).csv", table2, ';')
				DelimitedFiles.writedlm("$resultdir/$(casefilenameW)-$(k)-table_count_$(cutoff_s).csv", table3, ',')
			end
			local table = attributesl
			local table2 = attributesl
			local table3 = attributesl
			for i = 1:k
				Xek = (W[k][:,i:i] * H[k][i:i,:]) ./ Xe
				Xekm = Xek .> cutoff_s
				o = findmax(Xek; dims=2)
				table = hcat(table, map(i->locations[i], map(i->o[2][i][2], 1:length(attributesl))))
				table2 = hcat(table2, map(i->locations[Xekm[i,:]], 1:length(attributesl)))
				table3 = hcat(table3, map(i->sum(Xekm[i,:]), 1:length(attributesl)))
			end
			DelimitedFiles.writedlm("$resultdir/$(casefilenameH)-$(k)-table_max.csv", table, ',')
			DelimitedFiles.writedlm("$resultdir/$(casefilenameH)-$(k)-table_$(cutoff_s).csv", table2, ';')
			DelimitedFiles.writedlm("$resultdir/$(casefilenameH)-$(k)-table_count_$(cutoff_s).csv", table3, ',')
		end
	end
end

function signalorder(X::AbstractArray, dim=1)
	v = Vector{Int64}(undef, size(X, dim))
	for i = 1:size(X, dim)
		nt = ntuple(k->(k == dim ? i : Colon()), ndims(X))
		v[i] = findmax(X[nt...])[2]
	end
	sortperm(v), v
end

function signalorder(W::AbstractMatrix, H::AbstractMatrix; resultdir::AbstractString=".", loadassignements::Bool=true, Wclusterlabelcasefilename::AbstractString="Wmatrix", Hclusterlabelcasefilename::AbstractString="Hmatrix")
	k = size(H, 1)
	Hclusterlabels = NMFk.labelassignements(NMFk.robustkmeans(H, k; resultdir=resultdir, casefilename=Hclusterlabelcasefilename, load=loadassignements, save=true)[1].assignments)
	Hcs = sortperm(Hclusterlabels)
	clusterlabels = sort(unique(Hclusterlabels))
	Hsignalmap = NMFk.getsignalassignments(H, Hclusterlabels; clusterlabels=clusterlabels, dims=2)
	Hclustermap = Vector{Char}(undef, k)
	Hclustermap .= ' '
	for (j, i) in enumerate(clusterlabels)
		Hclustermap[Hsignalmap[j]] = i
	end
	Wclusterlabels = NMFk.labelassignements(NMFk.robustkmeans(permutedims(W), k; resultdir=resultdir, casefilename=Wclusterlabelcasefilename, load=loadassignements, save=true)[1].assignments)
	@assert clusterlabels == sort(unique(Wclusterlabels))
	Wsignalmap = NMFk.getsignalassignments(W[:,Hsignalmap], Wclusterlabels; clusterlabels=clusterlabels, dims=1)
	Wclusterlabelsnew = Vector{typeof(Wclusterlabels[1])}(undef, length(Wclusterlabels))
	Wclusterlabelsnew .= ' '
	Wsignalmapnew = Vector{String}(undef, length(Wclusterlabels))
	for (j, i) in enumerate(clusterlabels)
		iclustermap = Wsignalmap[j]
		Wclusterlabelsnew[Wclusterlabels .== i] .= clusterlabels[iclustermap]
		Wsignalmapnew[Wclusterlabels .== i] .= "S$(Wsignalmap[j])"
	end
	Wcs = sortperm(Wclusterlabelsnew)
	return Wclusterlabelsnew, Wsignalmapnew, Hclusterlabels, Hclustermap, Hsignalmap
end