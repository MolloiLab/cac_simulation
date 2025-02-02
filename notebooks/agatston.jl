### A Pluto.jl notebook ###
# v0.19.22

using Markdown
using InteractiveUtils

# This Pluto notebook uses @bind for interactivity. When running this notebook outside of Pluto, the following 'mock version' of @bind gives bound variables a default value (instead of an error).
macro bind(def, element)
    quote
        local iv = try Base.loaded_modules[Base.PkgId(Base.UUID("6e696c72-6542-2067-7265-42206c756150"), "AbstractPlutoDingetjes")].Bonds.initial_value catch; b -> missing; end
        local el = $(esc(element))
        global $(esc(def)) = Core.applicable(Base.get, el) ? Base.get(el) : iv(el)
        el
    end
end

# ╔═╡ f5acf58b-8436-4b0b-a170-746ba5475c10
# ╠═╡ show_logs = false
begin
	using Pkg
	Pkg.activate(".")

    using PlutoUI, Statistics, CSV, DataFrames, GLM, CairoMakie, HypothesisTests, Colors, MLJBase, DICOM, DICOMUtils, PhantomSegmentation, CalciumScoring, ImageMorphology, ImageFiltering, Noise, Distributions, DSP
    using StatsBase: quantile!, rmsd
end

# ╔═╡ 8219f406-7175-4573-ae37-642ef9c45b1b
TableOfContents()

# ╔═╡ ef30dc5c-0f83-485b-9718-669f292a87ec
md"""
## Load DICOMS
"""

# ╔═╡ 0697c534-0f9e-4aa1-a219-843f17d4070f
begin
    SCAN_NUMBER = 1
    VENDER = "100"
    SIZE = "small"
    # SIZE = "medium"
    # SIZE = "large"
    # DENSITY = "low"
    DENSITY = "normal"
    TYPE = "agatston"
    BASE_PATH = joinpath(dirname(pwd()), "images_new", SIZE, DENSITY)
end

# ╔═╡ 80592b38-6672-419e-9315-0e33046c42a8
md"""
**Everything below should be automatic, just scroll through to visually inspect that things make sense**
"""

# ╔═╡ d2f9de75-8b2a-40f2-98c0-5df90c32c8d6
root_path = joinpath(BASE_PATH, VENDER)

# ╔═╡ 813bf029-e475-4e65-a2ca-fdb6c23de115
dcm_path_list = dcm_list_builder(root_path)

# ╔═╡ ca10a4df-7e26-49c3-bdee-de9f0ffdc39c
pth = dcm_path_list[SCAN_NUMBER]

# ╔═╡ 670cfd3e-c32f-4357-a2b4-9b9d31d49c6a
scan = basename(pth)

# ╔═╡ 9dd34ad4-3576-4b85-b811-cafcd05b60a9
header, dcm_array, slice_thick_ori1 = dcm_reader(pth);

# ╔═╡ 29ef15d4-754a-4619-9abc-51182709bc5e
md"""
## Helper Functions
"""

# ╔═╡ e500136f-34f4-484c-8296-088ee69b0f48
function collect_tuple(tuple_array)
    row_num = size(tuple_array)
    col_num = length(tuple_array[1])
    container = zeros(Int64, row_num..., col_num)
    for i in 1:length(tuple_array)
        container[i, :] = collect(tuple_array[i])
    end
    return container
end

# ╔═╡ f6c6aa68-5e87-495e-b45b-ca96e61e9a69
function overlay_mask_bind(mask)
    indices = findall(x -> x == 1, mask)
    indices = Tuple.(indices)
    label_array = collect_tuple(indices)
    zs = unique(label_array[:, 3])
    return PlutoUI.Slider(1:length(zs); default=3, show_value=true)
end

# ╔═╡ 8a8e8a42-a823-47dd-b6eb-ef3dba4182d5
function overlay_mask_plot(array, mask, var, title::AbstractString)
    indices = findall(x -> x == 1, mask)
    indices = Tuple.(indices)
    label_array = collect_tuple(indices)
    zs = unique(label_array[:, 3])
    indices_lbl = findall(x -> x == zs[var], label_array[:, 3])

    fig = Figure()
    ax = Makie.Axis(fig[1, 1])
    ax.title = title
    heatmap!(array[:, :, zs[var]]; colormap=:grays)
    scatter!(
        label_array[:, 1][indices_lbl],
        label_array[:, 2][indices_lbl];
        markersize=1,
        color=:red,
    )
    return fig
end

# ╔═╡ 22ceda3c-3c30-4632-9052-4dd90cfabb24
function show_matrix(A::Matrix, red::Union{BitMatrix,Matrix{Bool}}=zeros(Bool, size(A)))
    base = RGB.(Gray.(A))

    base[red] .= RGB(1.0, 0.1, 0.1)

    # some tricks to show the pixels more clearly:
    s = max(size(A)...)
    if s >= 20
        min_size = 1200
        factor = min(5, min_size ÷ s)

        kron(base, ones(factor, factor))
    else
        base
    end
end

# ╔═╡ 4f486b1a-b272-4b7d-914c-baa9530ff4e3
function create_mask(array, mask)
    @assert size(array) == size(mask)
    idxs = findall(x -> x == true, mask)
    overlayed_mask = zeros(size(array))
    for idx in idxs
        overlayed_mask[idx] = array[idx]
    end
    return overlayed_mask
end

# ╔═╡ 8151a4eb-4139-48d2-8a25-14c350b30d6d
md"""
## Segment Heart
"""

# ╔═╡ 3c5e62f5-a435-43c4-a71e-256e3e0caacb
masked_array, center_insert, mask = mask_heart(header, dcm_array, size(dcm_array, 3) ÷ 2);

# ╔═╡ 14f7ed28-00ad-4b4e-be1f-b85f50c39b23
center_insert

# ╔═╡ 88f63f47-ac6b-4670-938b-9eda91550c8c
@bind a PlutoUI.Slider(1:size(masked_array, 3), default=10, show_value=true)

# ╔═╡ 06e6ec7d-e2e7-4348-b38c-8fde60a24807
heatmap(transpose(masked_array[:, :, a]); colormap=:grays)

# ╔═╡ 62e0db89-5a32-40d8-9264-684f7df58476
begin
    fig = Figure()

    ax = Makie.Axis(fig[1, 1])
    ax.title = "Raw DICOM Array"
    heatmap!(transpose(dcm_array[:, :, 4]); colormap=:grays)
    scatter!(
        center_insert[2]:center_insert[2],
        center_insert[1]:center_insert[1];
        markersize=10,
        color=:red,
    )
    fig
end

# ╔═╡ 09bd19ff-0db5-4a79-adb8-c3e202a4d7c7
begin
    fig2 = Figure()

    ax2 = Makie.Axis(fig2[1, 1])
    ax2.title = "Mask Array"
    heatmap!(transpose(mask); colormap=:grays)
    scatter!(
        center_insert[2]:center_insert[2],
        center_insert[1]:center_insert[1];
        markersize=10,
        color=:red,
    )
    fig2
end

# ╔═╡ 85a5667d-6606-4cce-8ca2-b3682422648e
begin
    fig3 = Figure()

    ax3 = Makie.Axis(fig3[1, 1])
    ax3.title = "Masked DICOM Array"
    heatmap!(transpose(masked_array[:, :, 5]); colormap=:grays)
    scatter!(
        center_insert[2]:center_insert[2],
        center_insert[1]:center_insert[1];
        markersize=10,
        color=:red,
    )
    fig3
end

# ╔═╡ 935767d5-046d-46b0-b1cc-01f85b0698f5
md"""
## Segment Calcium Rod
"""

# ╔═╡ 8742a48f-5309-448a-b705-1a19592eded9
begin
    global thresh
    if DENSITY == "low" && SIZE == "small"
        thresh = 60
    elseif DENSITY == "low" && SIZE == "large" && (VENDER == "120" || VENDER == "135")
        thresh = 75
    elseif DENSITY == "low" && SIZE == "medium"
        thresh = 75
    elseif DENSITY == "low"
        thresh = 60
    elseif DENSITY == "normal"
        thresh = 130
    end
end

# ╔═╡ d1cc731f-7a3d-412e-ae6c-a4cc9c4d1e9d
calcium_image, slice_CCI, quality_slice, cal_rod_slice = mask_rod(
    masked_array, header; calcium_threshold=thresh
);

# ╔═╡ 12320fe9-570d-4193-a743-9002f20ac9bf
begin
	array_filtered = abs.(mapwindow(median, calcium_image[:, :, 2], (3, 3)))
	bool_arr = array_filtered .> 0
	bool_arr_erode = (((erode(erode(bool_arr)))))
	c_img = calcium_image[:, :, 1:3]
	mask_cal_3D = zeros(size(c_img))
	for z in axes(c_img, 3)
		mask_cal_3D[:, :, z] = Bool.(erode(bool_arr_erode))
	end

	hu_calcium = mean(c_img[Bool.(mask_cal_3D)])
	ρ_calcium = 0.2
end

# ╔═╡ a8cbffa0-eaf0-425f-9f09-8c6043d47404
mu, sigma = mean(c_img[Bool.(mask_cal_3D)]), std(c_img[Bool.(mask_cal_3D)])

# ╔═╡ a15bd533-776e-44a7-bac4-6c37478d5969
@bind c PlutoUI.Slider(1:size(calcium_image, 3), default=cal_rod_slice, show_value=true)

# ╔═╡ 1665243d-4c39-4c69-bf35-bf30c4662c48
heatmap(transpose(calcium_image[:, :, c]); colormap=:grays)

# ╔═╡ 638286bd-35c6-4d18-84a2-15e92d2e815f
md"""
## Segment Calcium Inserts
"""

# ╔═╡ 77ff2fb9-d20c-4ec8-95a2-e95a677eadda
# mask_L_HD, mask_M_HD, mask_S_HD, mask_L_MD, mask_M_MD, mask_S_MD, mask_L_LD, mask_M_LD, mask_S_LD = mask_inserts_simulation(
#             dcm_array, masked_array, header, slice_CCI, center_insert
# );

# ╔═╡ 32562372-4ece-4586-8088-97ad26f1281c
begin
    root_new = joinpath(dirname(pwd()), "julia_arrays", SIZE)
    mask_L_HD = Array(CSV.read(joinpath(root_new, "mask_L_HD.csv"), DataFrame; header=false))
    mask_M_HD = Array(CSV.read(joinpath(root_new, "mask_M_HD.csv"), DataFrame; header=false))
    mask_S_HD = Array(CSV.read(joinpath(root_new, "mask_S_HD.csv"), DataFrame; header=false))
    mask_L_MD = Array(CSV.read(joinpath(root_new, "mask_L_MD.csv"), DataFrame; header=false))
    mask_M_MD = Array(CSV.read(joinpath(root_new, "mask_M_MD.csv"), DataFrame; header=false))
    mask_S_MD = Array(CSV.read(joinpath(root_new, "mask_S_MD.csv"), DataFrame; header=false))
    mask_L_LD = Array(CSV.read(joinpath(root_new, "mask_L_LD.csv"), DataFrame; header=false))
    mask_M_LD = Array(CSV.read(joinpath(root_new, "mask_M_LD.csv"), DataFrame; header=false))
    mask_S_LD = Array(CSV.read(joinpath(root_new, "mask_S_LD.csv"), DataFrame; header=false))
end;

# ╔═╡ 84938868-94a9-4fd0-8164-209122612f88
masks =
    mask_L_HD +
    mask_M_HD +
    mask_S_HD +
    mask_L_MD +
    mask_M_MD +
    mask_S_MD +
    mask_L_LD +
    mask_M_LD +
    mask_S_LD;

# ╔═╡ 229478be-eaac-4750-a3fd-790bfd9d541c
heatmap(masks; colormap=:grays)

# ╔═╡ d721bf89-a2f4-443a-a550-6bc2082d95a9
md"""
## Mass cal factor
"""

# ╔═╡ f67ca999-4ee5-44d0-b3af-6492f48a0426
output = calc_output(masked_array, header, 5, thresh, trues(3, 3));

# ╔═╡ fdbda290-3d6d-4134-a62d-aa9b80ad35c6
insert_centers = calc_centers(dcm_array, output, header, center_insert, slice_CCI)

# ╔═╡ e6636298-c93e-49c0-be89-2e714a5b0a77
center_large_LD = insert_centers[:Large_LD]

# ╔═╡ 44e8d33b-8f01-4894-91db-e9bc68eea754
rows, cols = Int(header[tag"Rows"]), Int(header[tag"Columns"])

# ╔═╡ c73cd156-dde4-446c-a4e2-b3c04283af4f
md"""
# Agatston Scoring
"""

# ╔═╡ a56d63f4-9f6b-48c4-8bf2-35f76acbf1d2
md"""
## High Density
"""

# ╔═╡ e12e4bb7-4ecd-4a7f-9ebd-70a80a18ac05
arr = masked_array[:, :, 4:6];

# ╔═╡ 03a30d17-76ae-4551-9d9f-5c5c22aaec73
begin
    mask_L_HD_3D = Array{Bool}(undef, size(arr))
    for z in 1:size(arr, 3)
        mask_L_HD_3D[:, :, z] = dilate(dilate(mask_L_HD))
    end
end;

# ╔═╡ 2ae3495e-e175-452e-8d80-b4f6e8b20f57
mean(arr[erode(erode(erode(erode(erode(mask_L_HD_3D)))))])

# ╔═╡ 9c68fb4e-d92d-4cb3-b04a-c3586212af4d
md"""
#### Dilated mask
"""

# ╔═╡ 12c89924-fc11-4696-b367-45457c5f255a
dilated_mask_L_HD = dilate(dilate(mask_L_HD_3D));

# ╔═╡ 262e4339-e041-4235-bc94-e6aae01d74a3
@bind g2 overlay_mask_bind(dilated_mask_L_HD)

# ╔═╡ d00f4649-e221-43a9-a504-5f61722eea91
overlay_mask_plot(arr, dilated_mask_L_HD, g2, "dilated mask")

# ╔═╡ a945ece4-2bd8-40db-bbe7-9747efa087e6
pixel_size = DICOMUtils.get_pixel_size(header)

# ╔═╡ befa5008-4bf5-425c-aeca-be71e89f06c9
mass_cal_factor, angle_0_200HA, water_rod_metrics = mass_calibration(
    masked_array, center_large_LD, center_insert, 2, cols, rows, pixel_size
)

# ╔═╡ 2d2d2600-dd70-4325-9032-4467882aff73
overlayed_mask_l_hd = create_mask(arr, dilated_mask_L_HD);

# ╔═╡ 73121968-a17a-4dcd-bbe5-96c0a04b5cb9
alg = Agatston()

# ╔═╡ 2268de53-7258-4f98-96ea-2fd0dd04ead2
function weighted_volume_fraction(vol, μ, σ, voxel_size, ρ_calcium)
	d = Distributions.Normal(μ, σ)

    scaled_array = zeros(size(vol))
    for i in axes(vol, 1)
        for j in axes(vol, 2)
            for z in axes(vol, 3)
                scaled_array[i, j, z] = Distributions.cdf(d, vol[i, j, z])
            end
        end
    end

    weighted_arr = zeros(size(vol))
    for z in axes(scaled_array, 3)
        kern = [0 0.2 0; 0.2 0.2 0.2; 0 0.2 0]
        weighted_arr[:, :, z] = DSP.conv(scaled_array[:, :, z], kern)[2:end-1, 2:end-1]
    end
	volume = sum(weighted_arr) * voxel_size
	mass = volume * ρ_calcium

    return volume, mass
end

# ╔═╡ d9f7f897-7525-4667-a414-3111296bc27f
agat_l_hd, vol_l_hd, mass_l_hd = score(overlayed_mask_l_hd, pixel_size, mass_cal_factor, alg)

# ╔═╡ 83267cb3-da34-440a-ad65-19b77fecd28e
voxel_size = pixel_size[1] * pixel_size[2] * pixel_size[3]

# ╔═╡ 71321aac-fd3d-4e58-bf8e-5078b97d5273
weighted_volume_fraction(overlayed_mask_l_hd, mu, sigma, voxel_size, ρ_calcium)

# ╔═╡ 332da204-0e58-443c-afcf-d036e6f7c111
begin
	vol, μ, σ = overlayed_mask_l_hd, mu, sigma
	d = Distributions.Normal(μ, σ)

    scaled_array = zeros(size(vol))
    for i in axes(vol, 1)
        for j in axes(vol, 2)
            for z in axes(vol, 3)
                scaled_array[i, j, z] = Distributions.cdf(d, vol[i, j, z])
            end
        end
    end

    weighted_arr = zeros(size(vol))
    for z in axes(scaled_array, 3)
        kern = [0 0.2 0; 0.2 0.2 0.2; 0 0.2 0]
        weighted_arr[:, :, z] = DSP.conv(scaled_array[:, :, z], kern)[2:end-1, 2:end-1]
    end
	calc_vol = sum(weighted_arr) * voxel_size
	calc_mass = calc_vol * ρ_calcium

    calc_vol, calc_mass
end

# ╔═╡ 7c4e9e90-5980-47ef-8170-f1d5d3277127
hist(vec(weighted_arr))

# ╔═╡ eda9865e-8291-4df9-8a1c-8865e832068c
length(unique(scaled_array))

# ╔═╡ d390e652-23a9-455d-87a0-3f8c54e2bb09
md"""
## Medium Density
"""

# ╔═╡ fcc751cd-120c-4c6f-828d-cf070b3466fa
begin
    mask_L_MD_3D = Array{Bool}(undef, size(arr))
    for z in 1:size(arr, 3)
        mask_L_MD_3D[:, :, z] = mask_L_MD
    end
end;

# ╔═╡ 96d09c06-e499-4390-b101-d663af7e5d75
md"""
#### Dilated mask
"""

# ╔═╡ fd344c0d-eb41-488c-9c6a-ef68cbd68637
dilated_mask_L_MD = dilate(dilate(mask_L_MD_3D));

# ╔═╡ 24fe0716-4e2f-47fb-b438-42d264bce384
@bind h2 overlay_mask_bind(dilated_mask_L_MD)

# ╔═╡ 37d44541-d30e-42be-b2d3-3423ac34c7dc
overlay_mask_plot(arr, dilated_mask_L_MD, h2, "dilated mask")

# ╔═╡ 8270b725-8748-4f48-8ac2-20ea81b80306
overlayed_mask_l_md = create_mask(arr, dilated_mask_L_MD);

# ╔═╡ acdf2d47-adfa-4ee0-9c9b-4d2bdb7e7aca
agat_l_md, vol_l_md,  mass_l_md = score(overlayed_mask_l_md, pixel_size, mass_cal_factor, alg)

# ╔═╡ fa8630bd-09ce-42f0-92b4-ec8cceef7504
weighted_volume_fraction(overlayed_mask_l_md, mu, sigma, voxel_size, ρ_calcium)

# ╔═╡ d5f66a85-966a-4cfc-8e8c-c2211e103f74
md"""
## Low Density
"""

# ╔═╡ 5a84502c-39ba-4234-a1b2-f852c7955193
begin
    mask_L_LD_3D = Array{Bool}(undef, size(arr))
    for z in 1:size(arr, 3)
        mask_L_LD_3D[:, :, z] = mask_L_LD
    end
end;

# ╔═╡ 53a04c71-9bcf-4af7-96de-71322df085b4
md"""
#### Dilated mask
"""

# ╔═╡ 473b7f74-904b-48b8-9a9f-d60eae5bbedd
dilated_mask_L_LD = dilate(dilate(mask_L_LD_3D));

# ╔═╡ 7237e02e-730e-4b6b-b7ef-60c8f19d5b3a
@bind i2 overlay_mask_bind(dilated_mask_L_LD)

# ╔═╡ bbd8b972-a2b7-4e2e-ae1f-e2d7a7c99a7b
overlay_mask_plot(arr, dilated_mask_L_LD, i2, "dilated mask")

# ╔═╡ 7c26c32f-d77d-41c4-b461-a2497549ecfb
overlayed_mask_l_ld = create_mask(arr, dilated_mask_L_LD);

# ╔═╡ ed7d7a23-3574-4cf2-9295-88386c013270
agat_l_ld, vol_l_ld, mass_l_ld = score(overlayed_mask_l_ld, pixel_size, mass_cal_factor, alg)

# ╔═╡ 4a094ffc-b8c2-4fc3-bb3a-6633229a6d6b
weighted_volume_fraction(overlayed_mask_l_ld, mu, sigma, voxel_size, ρ_calcium)

# ╔═╡ 73ac04c0-c8c8-4d55-aa6c-7e1747b951d2
md"""
# Score Medium Inserts
"""

# ╔═╡ 569182e7-e7fa-4063-9ba4-0e84ac7d5202
md"""
## High Density
"""

# ╔═╡ 4d0872f8-b728-4bfe-a96c-dfb53710a571
begin
    mask_M_HD_3D = Array{Bool}(undef, size(arr))
    for z in 1:size(arr, 3)
        mask_M_HD_3D[:, :, z] = mask_M_HD
    end
end;

# ╔═╡ d4e77ed5-d2c7-4288-a35d-34812617d089
md"""
#### Dilated mask
"""

# ╔═╡ 10546afe-656c-4837-9f21-f144023d56d4
dilated_mask_M_HD = dilate(dilate(dilate(dilate(mask_M_HD_3D))));

# ╔═╡ d1c3cd8a-258b-426f-bea0-aad31ad825f3
@bind j2 overlay_mask_bind(dilated_mask_M_HD)

# ╔═╡ 744681a4-70e5-49d9-bec1-29c4ecc80aea
overlay_mask_plot(arr, dilated_mask_M_HD, j2, "dilated mask")

# ╔═╡ fcffc8e9-2dca-425c-aad7-3a0be219b67c
overlayed_mask_m_hd = create_mask(arr, dilated_mask_M_HD);

# ╔═╡ 08141335-4566-4ba5-a29b-a39aa428b995
agat_m_hd, vol_m_hd, mass_m_hd = score(overlayed_mask_m_hd, pixel_size, mass_cal_factor, alg)

# ╔═╡ 200abfd1-87ef-4737-a8c6-410af4d3d9f0


# ╔═╡ c34ea971-4638-4348-8c7e-0342490421b1
md"""
## Medium Density
"""

# ╔═╡ 4b1a3793-fbc1-4d66-83c9-0dd8424c9334
begin
    mask_M_MD_3D = Array{Bool}(undef, size(arr))
    for z in 1:size(arr, 3)
        mask_M_MD_3D[:, :, z] = mask_M_MD
    end
end;

# ╔═╡ f4d289cf-25bf-4024-9be6-4397e03af0d3
md"""
#### Dilated mask
"""

# ╔═╡ 6dc948d0-d637-41bb-8c8e-6721d06f38e9
dilated_mask_M_MD = dilate(dilate(dilate(dilate(mask_M_MD_3D))));

# ╔═╡ a0f4c8df-2e3b-4de8-87f0-a180ee9a4ce1
@bind k2 overlay_mask_bind(dilated_mask_M_MD)

# ╔═╡ 4389d5d2-1a5c-4f96-8f03-d8824cd4381f
overlay_mask_plot(arr, dilated_mask_M_MD, k2, "dilated mask")

# ╔═╡ d656924f-72a8-4d91-8119-aa8c63ded3b8
overlayed_mask_m_md = create_mask(arr, dilated_mask_M_MD);

# ╔═╡ 732f75b0-4967-46e2-9777-21b6b4fd7990
agat_m_md, vol_m_md, mass_m_md = score(overlayed_mask_m_md, pixel_size, mass_cal_factor, alg)

# ╔═╡ 25743bee-e433-4b4d-91b9-27c9a24a3958
md"""
## Low Density
"""

# ╔═╡ f30257ed-4335-4ba6-9b91-93db7fd4ed9f
begin
    mask_M_LD_3D = Array{Bool}(undef, size(arr))
    for z in 1:size(arr, 3)
        mask_M_LD_3D[:, :, z] = mask_M_LD
    end
end;

# ╔═╡ 451821dc-8ff2-4042-af14-e52b94c298cb
md"""
#### Dilated mask
"""

# ╔═╡ 036386c8-591c-4478-bde1-33d973c458b9
dilated_mask_M_LD = dilate(dilate(dilate(dilate(dilate(mask_M_LD_3D)))));

# ╔═╡ 3fa6ba73-74c8-473a-8cd2-1cfe77381882
@bind l2 overlay_mask_bind(dilated_mask_M_LD)

# ╔═╡ 14cc065e-5150-4cad-a9bb-a562c0f4a9ee
overlay_mask_plot(arr, dilated_mask_M_LD, l2, "dilated mask")

# ╔═╡ fe2502fe-3ed6-4c16-94ad-6aafd87d1af9
overlayed_mask_m_ld = create_mask(arr, dilated_mask_M_LD);

# ╔═╡ 40d01237-f9fc-458e-adb1-4d3476e3a55c
agat_m_ld, vol_m_ld, mass_m_ld = score(overlayed_mask_m_ld, pixel_size, mass_cal_factor, alg)

# ╔═╡ a2b6908e-06a8-465c-931c-2c7895eb7fdd
md"""
# Score Small Inserts
"""

# ╔═╡ f30a694c-a9a5-4096-b03c-20e018f344b4
md"""
## High Density
"""

# ╔═╡ 324f5030-2bb5-4c2d-87bf-21069f86f898
begin
    mask_S_HD_3D = Array{Bool}(undef, size(arr))
    for z in 1:size(arr, 3)
        mask_S_HD_3D[:, :, z] = mask_S_HD
    end
end;

# ╔═╡ e2e5d32e-beab-470f-b753-c63bf58586ac
md"""
#### Dilated mask
"""

# ╔═╡ e0ae05d4-c910-453b-9851-445d36c715ae
dilated_mask_S_HD = dilate(dilate((dilate(dilate((mask_S_HD_3D))))));

# ╔═╡ 27d2277e-a4f5-46d5-b093-c41462622304
@bind m2 overlay_mask_bind(dilated_mask_S_HD)

# ╔═╡ 8637a05f-8db4-424e-a453-331bb564f181
overlay_mask_plot(arr, dilated_mask_S_HD, m2, "dilated mask")

# ╔═╡ 93158aaa-6622-4fa8-babc-959e7349ccba
overlayed_mask_s_hd = create_mask(arr, dilated_mask_S_HD);

# ╔═╡ 787547f0-cd60-43dd-8639-f9909d9197f3
agat_s_hd, vol_s_hd, mass_s_hd = score(overlayed_mask_s_hd, pixel_size, mass_cal_factor, alg)

# ╔═╡ ad7c62c8-52a8-4877-8b68-5be216f709cd
md"""
## Medium Density
"""

# ╔═╡ b72035ba-89ff-4405-aefc-b6af912d7af2
begin
    mask_S_MD_3D = Array{Bool}(undef, size(arr))
    for z in 1:size(arr, 3)
        mask_S_MD_3D[:, :, z] = mask_S_MD
    end
end;

# ╔═╡ 754d327d-2148-407f-aa8d-6cdf78bc55c3
md"""
#### Dilated mask
"""

# ╔═╡ bbb2d7ca-a25e-48bc-af10-af571d06009f
dilated_mask_S_MD = dilate(dilate((dilate(dilate(mask_S_MD_3D)))));

# ╔═╡ c311b2bc-0dd2-49a6-a295-cbecb44dbcd6
@bind n2 overlay_mask_bind(dilated_mask_S_MD)

# ╔═╡ 312bb63d-a933-462c-a513-5d20f905e950
overlay_mask_plot(arr, dilated_mask_S_MD, n2, "dilated mask")

# ╔═╡ 352a5ab8-b337-4e8a-bb44-8f977ec0675b
overlayed_mask_s_md = create_mask(arr, dilated_mask_S_MD);

# ╔═╡ f87fa716-e714-47fb-8e32-f7ed10c31999
agat_s_md, vol_s_md, mass_s_md = score(overlayed_mask_s_md, pixel_size, mass_cal_factor, alg)

# ╔═╡ e6d4b895-03c7-4913-8aaf-1af09260a603
md"""
## Low Density
"""

# ╔═╡ 15747d6b-9b96-4300-97cf-b5ec4550be90
begin
    mask_S_LD_3D = Array{Bool}(undef, size(arr))
    for z in 1:size(arr, 3)
        mask_S_LD_3D[:, :, z] = mask_S_LD
    end
end;

# ╔═╡ 0bd2712f-f02d-4287-a4b5-b7e626154234
md"""
#### Dilated mask
"""

# ╔═╡ 07e119cf-5443-44b4-8b24-4acf59803cae
dilated_mask_S_LD = dilate(dilate((dilate(dilate(mask_S_LD_3D)))));

# ╔═╡ c532d1b4-f852-4f49-882c-b9eab4ac721a
@bind o2 overlay_mask_bind(dilated_mask_S_LD)

# ╔═╡ 9698c301-59e0-4ca2-b3c3-3b989149558e
overlay_mask_plot(arr, dilated_mask_S_LD, o2, "dilated mask")

# ╔═╡ b48fbcd8-9c0b-4197-a6fd-2302ed0f644e
overlayed_mask_s_ld = create_mask(arr, dilated_mask_S_LD);

# ╔═╡ 5c9e783f-46d6-416d-a6ef-bb8b019b13ac
agat_s_ld, vol_s_ld, mass_s_ld = score(overlayed_mask_s_ld, pixel_size, mass_cal_factor, alg)

# ╔═╡ e603f95c-0a9a-4ad7-9a9f-8608fc982bd6
md"""
# Results
"""

# ╔═╡ deeafe24-aef9-4dd1-ba21-639c01fd918a
begin
    global density_array
    if DENSITY == "low"
        density_array = [0, 25, 50, 100]
    elseif DENSITY == "normal"
        density_array = [0, 200, 400, 800]
    end
end

# ╔═╡ 97aee49f-6666-4750-be7f-07c17b71dc29
inserts = ["Low Density", "Medium Density", "High Density"]

# ╔═╡ 59926926-4e0e-48cd-ac53-2132c95ccf0d
md"""
## Agatston
"""

# ╔═╡ 8fe8d2a6-d2a0-4aaa-98ae-2d065b3877b2
calculated_agat_large = [agat_l_ld, agat_l_md, agat_l_hd]

# ╔═╡ 28a0755a-50ad-46ce-adae-45e9ef850c30
calculated_agat_medium = [agat_m_ld, agat_m_md, agat_m_hd]

# ╔═╡ 3b78c0ca-f1d6-49b4-9144-e38a0e255d45
calculated_agat_small = [agat_s_ld, agat_s_md, agat_s_hd]

# ╔═╡ c12cc67a-c33a-4caf-b5d1-1664dd28b6ca
md"""
## Mass
"""

# ╔═╡ 5e3f2d07-3cc2-4c38-83d9-036bd7f38584
volume_gt = [7.065, 63.585, 176.625]

# ╔═╡ fa8d279b-8223-491e-9c7e-ab1cfc757ddb
ground_truth_mass_large = [
    volume_gt[3] * density_array[2] * 1e-3,
    volume_gt[3] * density_array[3] * 1e-3,
    volume_gt[3] * density_array[4] * 1e-3,
] # mg

# ╔═╡ f6d7c835-22ea-43e7-ad60-03a250803c91
calculated_mass_large = [mass_l_ld, mass_l_md, mass_l_hd]

# ╔═╡ cdb96a3e-11d7-429a-b2ae-7c3ca5b83d09
ground_truth_mass_medium = [
    volume_gt[2] * density_array[2] * 1e-3,
    volume_gt[2] * density_array[3] * 1e-3,
    volume_gt[2] * density_array[4] * 1e-3,
]

# ╔═╡ 8024abd9-22e1-4de0-a5e0-84728494e43a
calculated_mass_medium = [mass_m_ld, mass_m_md, mass_m_hd]

# ╔═╡ 0543e63d-cec3-4f1c-a751-59c03469ddf4
ground_truth_mass_small = [
    volume_gt[1] * density_array[2] * 1e-3,
    volume_gt[1] * density_array[3] * 1e-3,
    volume_gt[1] * density_array[4] * 1e-3,
]

# ╔═╡ 3dda3e1e-64c4-4b7e-bbd4-6aa1cebd7043
calculated_mass_small = [mass_s_ld, mass_s_md, mass_s_hd]

# ╔═╡ ea714f36-1f0f-43b4-85fe-6f483afdd32b
df = DataFrame(;
    scan=scan,
    inserts=inserts,
    calculated_agat_large=calculated_agat_large,
    calculated_agat_medium=calculated_agat_medium,
    calculated_agat_small=calculated_agat_small,
    ground_truth_mass_large=ground_truth_mass_large,
    calculated_mass_large=calculated_mass_large,
    ground_truth_mass_medium=ground_truth_mass_medium,
    calculated_mass_medium=calculated_mass_medium,
    ground_truth_mass_small=ground_truth_mass_small,
    calculated_mass_small=calculated_mass_small,
    mass_cal_factor=mass_cal_factor,
)

# ╔═╡ 44c88f17-bded-4e05-bb0f-94caaad7a541
begin
    fmass22 = Figure()
    axmass22 = Makie.Axis(fmass22[1, 1])

    scatter!(
        density_array[2:end],
        df[!, :ground_truth_mass_large];
        label="ground_truth_mass_large",
    )
    scatter!(
        density_array[2:end], df[!, :calculated_mass_large]; label="calculated_mass_large"
    )

    axmass22.title = "Mass Measurements (Large)"
    axmass22.ylabel = "Mass (mg)"
    axmass22.xlabel = "Density (mg/cm^3)"

    xlims!(axmass22, 0, 850)
    ylims!(axmass22, 0, 200)

    fmass22[1, 2] = Legend(fmass22, axmass22; framevisible=false)

    fmass22
end

# ╔═╡ a85b4e0e-353e-4d5b-9c81-16651a703cd5
begin
    fmass32 = Figure()
    axmass32 = Makie.Axis(fmass32[1, 1])

    scatter!(
        density_array[2:end],
        df[!, :ground_truth_mass_medium];
        label="ground_truth_mass_medium",
    )
    scatter!(
        density_array[2:end], df[!, :calculated_mass_medium]; label="calculated_mass_medium"
    )

    axmass32.title = "Mass Measurements (Medium)"
    axmass32.ylabel = "Mass (mg)"
    axmass32.xlabel = "Density (mg/cm^3)"

    xlims!(axmass32, 0, 850)
    ylims!(axmass32, 0, 85)

    fmass32[1, 2] = Legend(fmass32, axmass32; framevisible=false)

    fmass32
end

# ╔═╡ 67d28ece-79a5-408c-8e8f-1f84f16dd679
begin
    fmass42 = Figure()
    axmass42 = Makie.Axis(fmass42[1, 1])

    scatter!(
        density_array[2:end],
        df[!, :ground_truth_mass_small];
        label="ground_truth_mass_small",
    )
    scatter!(
        density_array[2:end], df[!, :calculated_mass_small]; label="calculated_mass_small"
    )

    axmass42.title = "Mass Measurements (Small)"
    axmass42.ylabel = "Mass (mg)"
    axmass42.xlabel = "Density (mg/cm^3)"

    xlims!(axmass42, 0, 850)
    ylims!(axmass42, 0, 10)

    fmass42[1, 2] = Legend(fmass42, axmass42; framevisible=false)

    fmass42
end

# ╔═╡ 722fb5f8-7443-41a3-acd8-01359d26e03c
md"""
### Save Results
"""

# ╔═╡ 3aa596a8-141d-4ce5-9047-c54ba76bc957
# if ~isdir(string(cd(pwd, "..") , "/output/", TYPE))
# 	mkdir(string(cd(pwd, "..") , "/output/", TYPE))
# end

# ╔═╡ 963377a8-4c68-4516-be15-699a9fefcb5a
# output_path = string(cd(pwd, "..") , "/output/", TYPE, "/", scan, ".csv")

# ╔═╡ 83524c6a-9504-4396-a219-e742edb1aa88
md"""
### Save full df
"""

# ╔═╡ 89251c1f-5895-4ae0-b6a9-87673ecd4530
dfs = []

# ╔═╡ 1d81feae-19aa-4146-980e-16ff39c6504c
push!(dfs, df)

# ╔═╡ 4f2902ba-9df0-4142-a21d-bddd2621e49f
# if length(dfs) == 12
#     global new_df = vcat(dfs[1:12]...)
#     output_path_new = string(cd(pwd, ".."), "/output/", TYPE, "/", "full.csv")
#     CSV.write(output_path_new, new_df)
# end

# ╔═╡ f9f81285-fc12-486b-9fb9-ab9d4d8014b0
# output_path_new = string(cd(pwd, "..") , "/output/", TYPE, "/", "full.csv")

# ╔═╡ Cell order:
# ╠═f5acf58b-8436-4b0b-a170-746ba5475c10
# ╠═8219f406-7175-4573-ae37-642ef9c45b1b
# ╟─ef30dc5c-0f83-485b-9718-669f292a87ec
# ╠═0697c534-0f9e-4aa1-a219-843f17d4070f
# ╟─80592b38-6672-419e-9315-0e33046c42a8
# ╠═d2f9de75-8b2a-40f2-98c0-5df90c32c8d6
# ╠═813bf029-e475-4e65-a2ca-fdb6c23de115
# ╠═ca10a4df-7e26-49c3-bdee-de9f0ffdc39c
# ╠═670cfd3e-c32f-4357-a2b4-9b9d31d49c6a
# ╠═9dd34ad4-3576-4b85-b811-cafcd05b60a9
# ╟─29ef15d4-754a-4619-9abc-51182709bc5e
# ╟─e500136f-34f4-484c-8296-088ee69b0f48
# ╟─f6c6aa68-5e87-495e-b45b-ca96e61e9a69
# ╟─8a8e8a42-a823-47dd-b6eb-ef3dba4182d5
# ╟─22ceda3c-3c30-4632-9052-4dd90cfabb24
# ╟─4f486b1a-b272-4b7d-914c-baa9530ff4e3
# ╟─8151a4eb-4139-48d2-8a25-14c350b30d6d
# ╠═3c5e62f5-a435-43c4-a71e-256e3e0caacb
# ╠═14f7ed28-00ad-4b4e-be1f-b85f50c39b23
# ╟─88f63f47-ac6b-4670-938b-9eda91550c8c
# ╠═06e6ec7d-e2e7-4348-b38c-8fde60a24807
# ╟─62e0db89-5a32-40d8-9264-684f7df58476
# ╟─09bd19ff-0db5-4a79-adb8-c3e202a4d7c7
# ╟─85a5667d-6606-4cce-8ca2-b3682422648e
# ╟─935767d5-046d-46b0-b1cc-01f85b0698f5
# ╠═8742a48f-5309-448a-b705-1a19592eded9
# ╠═d1cc731f-7a3d-412e-ae6c-a4cc9c4d1e9d
# ╠═12320fe9-570d-4193-a743-9002f20ac9bf
# ╠═a8cbffa0-eaf0-425f-9f09-8c6043d47404
# ╟─a15bd533-776e-44a7-bac4-6c37478d5969
# ╠═1665243d-4c39-4c69-bf35-bf30c4662c48
# ╟─638286bd-35c6-4d18-84a2-15e92d2e815f
# ╠═77ff2fb9-d20c-4ec8-95a2-e95a677eadda
# ╠═32562372-4ece-4586-8088-97ad26f1281c
# ╠═84938868-94a9-4fd0-8164-209122612f88
# ╠═229478be-eaac-4750-a3fd-790bfd9d541c
# ╟─d721bf89-a2f4-443a-a550-6bc2082d95a9
# ╠═f67ca999-4ee5-44d0-b3af-6492f48a0426
# ╠═fdbda290-3d6d-4134-a62d-aa9b80ad35c6
# ╠═e6636298-c93e-49c0-be89-2e714a5b0a77
# ╠═44e8d33b-8f01-4894-91db-e9bc68eea754
# ╠═befa5008-4bf5-425c-aeca-be71e89f06c9
# ╟─c73cd156-dde4-446c-a4e2-b3c04283af4f
# ╟─a56d63f4-9f6b-48c4-8bf2-35f76acbf1d2
# ╠═e12e4bb7-4ecd-4a7f-9ebd-70a80a18ac05
# ╠═03a30d17-76ae-4551-9d9f-5c5c22aaec73
# ╠═2ae3495e-e175-452e-8d80-b4f6e8b20f57
# ╟─9c68fb4e-d92d-4cb3-b04a-c3586212af4d
# ╠═12c89924-fc11-4696-b367-45457c5f255a
# ╟─262e4339-e041-4235-bc94-e6aae01d74a3
# ╠═d00f4649-e221-43a9-a504-5f61722eea91
# ╠═a945ece4-2bd8-40db-bbe7-9747efa087e6
# ╠═2d2d2600-dd70-4325-9032-4467882aff73
# ╠═73121968-a17a-4dcd-bbe5-96c0a04b5cb9
# ╠═2268de53-7258-4f98-96ea-2fd0dd04ead2
# ╠═d9f7f897-7525-4667-a414-3111296bc27f
# ╠═83267cb3-da34-440a-ad65-19b77fecd28e
# ╠═71321aac-fd3d-4e58-bf8e-5078b97d5273
# ╠═332da204-0e58-443c-afcf-d036e6f7c111
# ╠═7c4e9e90-5980-47ef-8170-f1d5d3277127
# ╠═eda9865e-8291-4df9-8a1c-8865e832068c
# ╟─d390e652-23a9-455d-87a0-3f8c54e2bb09
# ╠═fcc751cd-120c-4c6f-828d-cf070b3466fa
# ╟─96d09c06-e499-4390-b101-d663af7e5d75
# ╠═fd344c0d-eb41-488c-9c6a-ef68cbd68637
# ╟─24fe0716-4e2f-47fb-b438-42d264bce384
# ╠═37d44541-d30e-42be-b2d3-3423ac34c7dc
# ╠═8270b725-8748-4f48-8ac2-20ea81b80306
# ╠═acdf2d47-adfa-4ee0-9c9b-4d2bdb7e7aca
# ╠═fa8630bd-09ce-42f0-92b4-ec8cceef7504
# ╟─d5f66a85-966a-4cfc-8e8c-c2211e103f74
# ╠═5a84502c-39ba-4234-a1b2-f852c7955193
# ╟─53a04c71-9bcf-4af7-96de-71322df085b4
# ╠═473b7f74-904b-48b8-9a9f-d60eae5bbedd
# ╟─7237e02e-730e-4b6b-b7ef-60c8f19d5b3a
# ╠═bbd8b972-a2b7-4e2e-ae1f-e2d7a7c99a7b
# ╠═7c26c32f-d77d-41c4-b461-a2497549ecfb
# ╠═ed7d7a23-3574-4cf2-9295-88386c013270
# ╠═4a094ffc-b8c2-4fc3-bb3a-6633229a6d6b
# ╟─73ac04c0-c8c8-4d55-aa6c-7e1747b951d2
# ╟─569182e7-e7fa-4063-9ba4-0e84ac7d5202
# ╠═4d0872f8-b728-4bfe-a96c-dfb53710a571
# ╟─d4e77ed5-d2c7-4288-a35d-34812617d089
# ╠═10546afe-656c-4837-9f21-f144023d56d4
# ╟─d1c3cd8a-258b-426f-bea0-aad31ad825f3
# ╠═744681a4-70e5-49d9-bec1-29c4ecc80aea
# ╠═fcffc8e9-2dca-425c-aad7-3a0be219b67c
# ╠═08141335-4566-4ba5-a29b-a39aa428b995
# ╠═200abfd1-87ef-4737-a8c6-410af4d3d9f0
# ╟─c34ea971-4638-4348-8c7e-0342490421b1
# ╠═4b1a3793-fbc1-4d66-83c9-0dd8424c9334
# ╟─f4d289cf-25bf-4024-9be6-4397e03af0d3
# ╠═6dc948d0-d637-41bb-8c8e-6721d06f38e9
# ╟─a0f4c8df-2e3b-4de8-87f0-a180ee9a4ce1
# ╠═4389d5d2-1a5c-4f96-8f03-d8824cd4381f
# ╠═d656924f-72a8-4d91-8119-aa8c63ded3b8
# ╠═732f75b0-4967-46e2-9777-21b6b4fd7990
# ╟─25743bee-e433-4b4d-91b9-27c9a24a3958
# ╠═f30257ed-4335-4ba6-9b91-93db7fd4ed9f
# ╟─451821dc-8ff2-4042-af14-e52b94c298cb
# ╠═036386c8-591c-4478-bde1-33d973c458b9
# ╟─3fa6ba73-74c8-473a-8cd2-1cfe77381882
# ╠═14cc065e-5150-4cad-a9bb-a562c0f4a9ee
# ╠═fe2502fe-3ed6-4c16-94ad-6aafd87d1af9
# ╠═40d01237-f9fc-458e-adb1-4d3476e3a55c
# ╟─a2b6908e-06a8-465c-931c-2c7895eb7fdd
# ╟─f30a694c-a9a5-4096-b03c-20e018f344b4
# ╠═324f5030-2bb5-4c2d-87bf-21069f86f898
# ╟─e2e5d32e-beab-470f-b753-c63bf58586ac
# ╠═e0ae05d4-c910-453b-9851-445d36c715ae
# ╟─27d2277e-a4f5-46d5-b093-c41462622304
# ╠═8637a05f-8db4-424e-a453-331bb564f181
# ╠═93158aaa-6622-4fa8-babc-959e7349ccba
# ╠═787547f0-cd60-43dd-8639-f9909d9197f3
# ╟─ad7c62c8-52a8-4877-8b68-5be216f709cd
# ╠═b72035ba-89ff-4405-aefc-b6af912d7af2
# ╟─754d327d-2148-407f-aa8d-6cdf78bc55c3
# ╠═bbb2d7ca-a25e-48bc-af10-af571d06009f
# ╟─c311b2bc-0dd2-49a6-a295-cbecb44dbcd6
# ╠═312bb63d-a933-462c-a513-5d20f905e950
# ╠═352a5ab8-b337-4e8a-bb44-8f977ec0675b
# ╠═f87fa716-e714-47fb-8e32-f7ed10c31999
# ╟─e6d4b895-03c7-4913-8aaf-1af09260a603
# ╠═15747d6b-9b96-4300-97cf-b5ec4550be90
# ╟─0bd2712f-f02d-4287-a4b5-b7e626154234
# ╠═07e119cf-5443-44b4-8b24-4acf59803cae
# ╟─c532d1b4-f852-4f49-882c-b9eab4ac721a
# ╠═9698c301-59e0-4ca2-b3c3-3b989149558e
# ╠═b48fbcd8-9c0b-4197-a6fd-2302ed0f644e
# ╠═5c9e783f-46d6-416d-a6ef-bb8b019b13ac
# ╟─e603f95c-0a9a-4ad7-9a9f-8608fc982bd6
# ╠═deeafe24-aef9-4dd1-ba21-639c01fd918a
# ╠═97aee49f-6666-4750-be7f-07c17b71dc29
# ╟─59926926-4e0e-48cd-ac53-2132c95ccf0d
# ╠═8fe8d2a6-d2a0-4aaa-98ae-2d065b3877b2
# ╠═28a0755a-50ad-46ce-adae-45e9ef850c30
# ╠═3b78c0ca-f1d6-49b4-9144-e38a0e255d45
# ╠═ea714f36-1f0f-43b4-85fe-6f483afdd32b
# ╟─c12cc67a-c33a-4caf-b5d1-1664dd28b6ca
# ╠═5e3f2d07-3cc2-4c38-83d9-036bd7f38584
# ╠═fa8d279b-8223-491e-9c7e-ab1cfc757ddb
# ╠═f6d7c835-22ea-43e7-ad60-03a250803c91
# ╠═cdb96a3e-11d7-429a-b2ae-7c3ca5b83d09
# ╠═8024abd9-22e1-4de0-a5e0-84728494e43a
# ╠═0543e63d-cec3-4f1c-a751-59c03469ddf4
# ╠═3dda3e1e-64c4-4b7e-bbd4-6aa1cebd7043
# ╟─44c88f17-bded-4e05-bb0f-94caaad7a541
# ╟─a85b4e0e-353e-4d5b-9c81-16651a703cd5
# ╟─67d28ece-79a5-408c-8e8f-1f84f16dd679
# ╟─722fb5f8-7443-41a3-acd8-01359d26e03c
# ╠═3aa596a8-141d-4ce5-9047-c54ba76bc957
# ╠═963377a8-4c68-4516-be15-699a9fefcb5a
# ╟─83524c6a-9504-4396-a219-e742edb1aa88
# ╠═89251c1f-5895-4ae0-b6a9-87673ecd4530
# ╠═1d81feae-19aa-4146-980e-16ff39c6504c
# ╠═4f2902ba-9df0-4142-a21d-bddd2621e49f
# ╠═f9f81285-fc12-486b-9fb9-ab9d4d8014b0
