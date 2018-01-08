#!/usr/bin/env python

# Compare two datasets, either two MODIS, or two VIIRS, or one MODIS
# versus one VIIRS. 
# 
# Zhan Li, zhan.li@umb.edu
# Created: Fri Nov  3 20:31:52 EDT 2017

import os
import sys
import argparse
import itertools
import warnings

import h5py
import numpy as np

from osgeo import gdal, gdal_array, osr

import colorama
colorama.init(autoreset=True)
# define some color schemes for message output control
colorWarnStr = lambda msg: colorama.Fore.YELLOW + str(msg) + colorama.Style.RESET_ALL
colorErrorStr = lambda msg: colorama.Fore.RED + str(msg) + colorama.Style.RESET_ALL
colorInfoStr = lambda msg: colorama.Fore.GREEN + str(msg) + colorama.Style.RESET_ALL
colorDimStr = lambda msg: colorama.Style.DIM + str(msg) + colorama.Style.RESET_ALL
colorLogStr = lambda msg: str(msg)
colorResetStr = lambda msg: colorama.Style.RESET_ALL + str(msg)

import matplotlib as mpl
mpl.use('Agg')
import matplotlib.pyplot as plt
from mpl_toolkits.axes_grid1 import make_axes_locatable

mpl.rc(("xtick", "ytick"), labelsize=8)

def getCmdArgs():
    p = argparse.ArgumentParser(description="Compare two datasets from MODIS and/or VIIRS")
    
    p.add_argument("--files", dest="files", nargs="+", required=True, default=None, help="Input HDF5 files from which datasets to be compared are extracted.")
    p.add_argument("--datasets", dest="datasets", nargs="+", required=True, default=None, help="Names of datasets in the corresponding input HDF5 files to be compared.")
    p.add_argument("--band", dest="band", required=False, nargs="+", type=int, default=None, help="When a dataset is multiband, e.g. BRDF_Albedo_Parameters that is a three-dimensional matrix, this option provides the index to the band to read from each dataset, with the first band as 1. Default: all 1, i.e. the first band.")
    p.add_argument("--outdir", dest="outdir", required=True, default=None, help="Directory of output images of datasets and figures of comparisons.")
    p.add_argument("--labels", dest="labels", nargs="+", required=True, default=None, help="Short-name labels of the input datasets")

    p.add_argument("--stats", dest="stats", required=False, action="store_true", help="If given, generate the following statistics for pixel-by-pixel differences between every two input bands or datasets, mean, standard deviation, minimum, 5 percentile, 25 percentile, median, 75 percentile, 95 percentile, maximum. If given --ocsv, output the statistics to the CSV file; otherwise, output to stdout.")
    p.add_argument("--ocsv", dest="ocsv", required=False, default=None, help="Name of a CSV file to output the list of metadata attributes for each dataset, and if given --stats, the statistics.")

    p.add_argument("--transform_func", dest="transfunc", required=False, default=None, choices=["popcount"], help="Name of a function to transform pixel values. Choices: ['popcount']. Default: no transformation.")

    p.add_argument("--scale_factor", dest="scale_factor", nargs="+", type=float, required=False, default=None, help="Pixel value * scale factor will be used in the comparison and plots. Default: all 1.")
    p.add_argument("--stretch_min", dest="stretch_min", nargs="+", type=float, required=False, default=None, help="Minimum pixel value AFTER applying scale factor for each dataset as the plot boundaries. Default: all 0.")
    p.add_argument("--stretch_max", dest="stretch_max", nargs="+", type=float, required=False, default=None, help="Maximum pixel value AFTER applying scale factor for each dataset as the plot boundaries. Default: all 1000.")
    p.add_argument("--bin_size", dest="bin_size", nargs="+", type=float, required=False, default=None, help="Bin size (width) for pixel values AFTER applying scale factors to plot histograms. Default: all 1.")

    p.add_argument("--fig_width", dest="fig_width", type=float, required=False, default=5, help="Width of output figures, in inches, the height of an output figure will be automatically adjusted. Default: 5 inches.")

    cmdargs = p.parse_args()

    if cmdargs.scale_factor is None:
        cmdargs.scale_factor = (1,)*len(cmdargs.files)
    if cmdargs.stretch_min is None:
        cmdargs.stretch_min = (0,)*len(cmdargs.files)
    if cmdargs.stretch_max is None:
        cmdargs.stretch_max = (1000,)*len(cmdargs.files)
    if cmdargs.bin_size is None:
        cmdargs.bin_size = (1,)*len(cmdargs.files)
    if cmdargs.band is None:
        cmdargs.band = (1,)*len(cmdargs.files)

    if len(cmdargs.files) != len(cmdargs.datasets):
        raise RuntimeError(colorErrorStr("Numbers of input files and datasets names must be equal and one to one."))
    if len(cmdargs.files) != len(cmdargs.band):
        raise RuntimeError(colorErrorStr("Numbers of input files and band indexes must be equal and one to one."))
    if len(cmdargs.files) != len(cmdargs.labels):
        raise RuntimeError(colorErrorStr("Numbers of input files and labels must be equal and one to one."))
    if len(cmdargs.files) != len(cmdargs.scale_factor):
        raise RuntimeError(colorErrorStr("Numbers of input files and scale factors must be equal and one to one."))
    if len(cmdargs.files) != len(cmdargs.stretch_min):
        raise RuntimeError(colorErrorStr("Numbers of input files and strech minimums must be equal and one to one."))
    if len(cmdargs.files) != len(cmdargs.stretch_max):
        raise RuntimeError(colorErrorStr("Numbers of input files and strech maximums must be equal and one to one."))
    if len(cmdargs.files) != len(cmdargs.bin_size):
        raise RuntimeError(colorErrorStr("Numbers of input files and bin sizes must be equal and one to one."))

    if (cmdargs.ocsv is not None) and (not cmdargs.stats):
        raise RuntimeError(colorErrorStr("Option stats is not turned on for writing to the given CSV file."))

    return cmdargs

def main(cmdargs):
    infiles = cmdargs.files
    inds = cmdargs.datasets
    inband = cmdargs.band
    inlabels = cmdargs.labels
    outdir = cmdargs.outdir
    scale_factor = cmdargs.scale_factor
    stretch_min = cmdargs.stretch_min
    stretch_max = cmdargs.stretch_max
    bin_size = cmdargs.bin_size
    fig_width = cmdargs.fig_width
    cmap_name = 'jet'
    dpi = 300
    mem_size = 50e6 # in unit of byte, 50MB memory per image preview
    transfunc = cmdargs.transfunc

    do_stats = cmdargs.stats
    outcsvfile = cmdargs.ocsv

    fobj_list = [h5py.File(fname, "r") for fname in infiles]

    dsname_list = [fobj['/'].visit(lambda name: name if ids in name else None) for fobj, ids in itertools.izip(fobj_list, inds)]
    dsname_found = True
    for i, dsname in enumerate(dsname_list):
        if dsname is None:
            print colorErrorStr("Dataset name {0:s} NOT found in {1:s}".format(inds[i], infiles[i]))
            dsname_found = False
    if not dsname_found:
        raise RuntimeError(colorErrorStr("Incorrect dataset name!"))

    sds_list = [fobj[dsname] for fobj, dsname in itertools.izip(fobj_list, dsname_list)]
    # find fill value
    fillvalue_list = []
    for i, (fobj, dsname) in enumerate(itertools.izip(fobj_list, dsname_list)):
        fill_found = False
        for tmp in fobj[dsname].attrs.keys():
            if 'FILL' in tmp.upper():
                fillvalue_list.append(fobj[dsname].attrs[tmp])
                fill_found = True
                break
        if not fill_found:
            fillvalue_list.append(None)
            print colorWarnStr("{0:s}:{1:s}, no fill value!".format(os.path.basename(infiles[i]), dsname))
    fillvalue_list = [fv if (np.isscalar(fv) or fv is None) else fv[0] for fv in fillvalue_list]
    if np.sum([fv is None for fv in fillvalue_list]) > 0:
        fillvalue_list = [np.iinfo(sds.dtype).max if fv is None else fv for sds, fv in itertools.izip(sds_list, fillvalue_list)]
        warnings.warn(colorDimStr("Some input datasets miss fill value. Use the maximum values of their data types."), RuntimeWarning)
        print fillvalue_list

    # List metadata of the dataset
    print colorInfoStr("-"*70)
    print colorInfoStr("Metadata names of the datasets")
    for fobj, dsname in itertools.izip(fobj_list, dsname_list):
        print colorInfoStr(str(fobj[dsname].attrs.keys()))
    print
    print colorInfoStr("Metadata values of the datasets")
    for fobj, dsname in itertools.izip(fobj_list, dsname_list):
        print colorInfoStr(str(fobj[dsname].attrs.values()))
    print colorInfoStr("-"*70)

    for sds in sds_list:
        if sds.ndim != sds_list[0].ndim:
            raise RuntimeError(colorErrorStr("Input datasets must have the same dimension!"))
        for i in range(sds_list[0].ndim):
            if sds.shape[i] != sds_list[0].shape[i]:
                raise RuntimeError(colorErrorStr("Input datasets must have the same dimension!"))

    # if any dataset is multiband but without an input of valid band
    # index to read image data, raise an error.
    for sds, ib in itertools.izip(sds_list, inband):
        if sds.ndim > 2 and ib > sds.ndim:
            raise RuntimeError(colorErrorStr("Input band index {2:d} is valid for the dataset {0:s}, in the file {1:s}".format(sds.name, sds.file.filename, ib)))

    # Large amount of pixels to compare for generating scatter density
    # plot. First build a scatter density array by going through the
    # data chunk by chunk. The chunk size is determined by the
    # prescribed memory size limit.
    chunk_xsize_list = [int(np.sqrt(mem_size/sds.dtype.itemsize)) for sds in sds_list]
    chunk_ysize_list = chunk_xsize_list
    nchunk_x_list = [np.ceil(sds.shape[1]/cx).astype(int) for sds, cx in itertools.izip(sds_list, chunk_xsize_list)]
    nchunk_y_list = [np.ceil(sds.shape[0]/cy).astype(int) for sds, cy in itertools.izip(sds_list, chunk_ysize_list)]
    nchunk_x_list = [ncx if ncx>0 else 1 for ncx in nchunk_x_list]
    nchunk_y_list = [ncy if ncy>0 else 1 for ncy in nchunk_y_list]

    bins_list = [np.arange(smin-bw*0.5, smax+bw*1.5, bw) for smin, smax, bw in itertools.izip(stretch_min, stretch_max, bin_size)]

    if do_stats:
        tmplen = len(sds_list) * (len(sds_list)-1) / 2
        tmp_x_cnt = np.zeros(tmplen)
        tmp_x_sum = np.zeros(tmplen)
        tmp_x2_sum = np.zeros(tmplen)
        hist_list = [np.zeros(2, dtype=np.int) for i in range(tmplen)]
        binrange_list = [np.array([0,1], dtype=np.int) for i in range(tmplen)]
        fmtstr = ",".join(["{{{0:d}:s}}".format(i) for i in range(4)])
        fmtstr = fmtstr + "," + ",".join(["{{4[{0:d}]:.3g}}".format(i) for i in range(10)])
        fmtstr = fmtstr + "\n"
        outstats_str = "file_left,dataset_left,file_right,dataset_right,mean,std,rms,min,5pct,25pct,median,75pct,95pct,max\n"

    for idx1, idx2 in itertools.combinations(range(len(sds_list)), 2):
        sds1, sds2 = sds_list[idx1], sds_list[idx2]
        fv1, fv2 = fillvalue_list[idx1], fillvalue_list[idx2]
        bins1, bins2 = bins_list[idx1], bins_list[idx2]

        cx1, cx2 = chunk_xsize_list[idx1], chunk_xsize_list[idx2]
        ncx1, ncx2 = nchunk_x_list[idx1], nchunk_x_list[idx1]
        cy1, cy2 = chunk_ysize_list[idx1], chunk_ysize_list[idx2]
        ncy1, ncy2 = nchunk_y_list[idx1], nchunk_y_list[idx1]

        ncx, cx, ncy, cy = ncx1, cx1, ncy1, cy1
        final_hist2d_arr = np.zeros((len(bins1)-1, len(bins2)-1))
        final_hist1d_arr1 = np.zeros(len(bins1)-1)
        final_hist1d_arr2 = np.zeros(len(bins2)-1)
        final_cmhist1d_arr1 = np.zeros(len(bins1)-1)
        final_cmhist1d_arr2 = np.zeros(len(bins2)-1)

        if do_stats:
            tmp_x_cnt, tmp_x_sum, tmp_x2_sum = 0, 0, 0
            diff_hist = np.zeros(2, dtype=np.int)
            diff_binrange = np.array([0, 1], dtype=np.int)
            diff_scale_factor_inv = 1./np.min([scale_factor[idx1], scale_factor[idx2]])

        for ix in range(ncx):
            for iy in range(ncy):
                sys.stdout.write("Reading chunk row, col: {0:d}/{1:d}, {2:d}/{3:d} ... ".format(iy+1, ncy, ix+1, ncx))
                sys.stdout.flush()
                tmpxidx1 = sds1.shape[1] if ix==ncx-1 else (ix+1)*cx
                tmpxidx2 = sds2.shape[1] if ix==ncx-1 else (ix+1)*cx
                tmpyidx1 = sds1.shape[0] if iy==ncy-1 else (iy+1)*cy
                tmpyidx2 = sds2.shape[0] if iy==ncy-1 else (iy+1)*cy

                tmpdata1 = sds1[iy*cy:tmpyidx1, ix*cx:tmpxidx1].flatten()
                tmpdata2 = sds2[iy*cy:tmpyidx2, ix*cx:tmpxidx2].flatten()
                if sds1.ndim == 2:
                    tmpdata1 = sds1[iy*cy:tmpyidx1, ix*cx:tmpxidx1].flatten()
                elif sds1.ndim == 3:
                    tmpdata1 = sds1[iy*cy:tmpyidx1, ix*cx:tmpxidx1, inband[idx1]-1].flatten()
                else:
                    raise RuntimeError(colorErrorStr("Unexpected number of dimensions of input dataset!"))
                if sds2.ndim == 2:
                    tmpdata2 = sds2[iy*cy:tmpyidx2, ix*cx:tmpxidx2].flatten()
                elif sds2.ndim == 3:
                    tmpdata2 = sds2[iy*cy:tmpyidx2, ix*cx:tmpxidx2, inband[idx2]-1].flatten()
                else:
                    raise RuntimeError(colorErrorStr("Unexpected number of dimensions of input dataset!"))

                if transfunc == "popcount":
                    sys.stdout.write("Transforming the data ... ")
                    sys.stdout.flush()
                    tmpdata1 = popcount_func(tmpdata1, fv1)
                    tmpdata2 = popcount_func(tmpdata2, fv2)
                
                # apply scale factor
                tmpflag = tmpdata1==fv1
                tmpdata1 = tmpdata1 * scale_factor[idx1]
                tmpdata1[tmpflag] = fv1
                tmpflag = tmpdata2==fv2
                tmpdata2 = tmpdata2 * scale_factor[idx2]
                tmpdata2[tmpflag] = fv2

                tmpflag = reduce(np.logical_and, [tmpdata1!=fv1, tmpdata2!=fv2])
                hist2d_arr, hist2d_xed, hist2d_yed = np.histogram2d(tmpdata1[tmpflag], tmpdata2[tmpflag], bins=[bins1, bins2])
                final_hist2d_arr = final_hist2d_arr + hist2d_arr
                
                hist1d_arr, hist1d_bed1 = np.histogram(tmpdata1[tmpdata1!=fv1], bins=bins1)
                final_hist1d_arr1 = final_hist1d_arr1 + hist1d_arr
                hist1d_arr, hist1d_bed2 = np.histogram(tmpdata2[tmpdata2!=fv2], bins=bins2)
                final_hist1d_arr2 = final_hist1d_arr2 + hist1d_arr

                hist1d_arr, hist1d_bed1 = np.histogram(tmpdata1[tmpflag], bins=bins1)
                final_cmhist1d_arr1 = final_cmhist1d_arr1 + hist1d_arr
                hist1d_arr, hist1d_bed2 = np.histogram(tmpdata2[tmpflag], bins=bins2)
                final_cmhist1d_arr2 = final_cmhist1d_arr2 + hist1d_arr

                if do_stats:
                    sys.stdout.write("Digesting data to estimate difference stats ... ")
                    sys.stdout.flush()

                    tmpdiff = (tmpdata1.astype(np.double) - tmpdata2.astype(np.double)) * diff_scale_factor_inv
                    tmpdiff = tmpdiff[tmpflag]
                    if tmpdiff.size == 0:
                        sys.stdout.write("\r")
                        continue
                    tmp_x_cnt = tmp_x_cnt + tmpdiff.size
                    tmp_x_sum = tmp_x_sum + np.sum(tmpdiff)
                    tmp_x2_sum = tmp_x2_sum + np.sum(tmpdiff * tmpdiff)
                    
                    tmpmax = np.max(tmpdiff)
                    tmpmin = np.min(tmpdiff)
                    if tmpmax > diff_binrange[1]:
                        diff_hist = np.append(diff_hist, np.zeros(int(tmpmax-diff_binrange[1])))
                        diff_binrange[1] = tmpmax
                    if tmpmin < diff_binrange[0]:
                        diff_hist = np.append(np.zeros(int(diff_binrange[0]-tmpmin)), diff_hist)
                        diff_binrange[0] = tmpmin
                    tmpbins = np.arange(diff_binrange[0]-0.5, diff_binrange[1]+1.5)
                    tmphist1d, diffhist_bed = np.histogram(tmpdiff, bins=tmpbins)
                    diff_hist = diff_hist + tmphist1d

                sys.stdout.write("\r")

        if do_stats:
            # mean, std, rms, min, 5%, 25%, median, 75%, 95%, max
            diff_stats = np.zeros(10)
            pct_list = [0, 5, 25, 50, 75, 95, 100]
            diff_stats[0] = tmp_x_sum / tmp_x_cnt
            diff_stats[1] = np.sqrt(tmp_x2_sum/tmp_x_cnt - diff_stats[0]*diff_stats[0])
            diff_stats[2] = np.sqrt(tmp_x2_sum/tmp_x_cnt)
            tmpcs = np.cumsum(diff_hist) / float(np.sum(diff_hist)) * 100
            tmpidx = np.searchsorted(tmpcs, pct_list)
            tmpidx[0], tmpidx[-1] = 0, -1
            diff_stats[3:] = np.arange(diff_binrange[0], diff_binrange[1]+1)[tmpidx]
            diff_stats = diff_stats / diff_scale_factor_inv
            diffhist_bed = diffhist_bed / diff_scale_factor_inv
            outstats_str = outstats_str \
                           + fmtstr.format(infiles[idx1], dsname_list[idx1], 
                                           infiles[idx2], dsname_list[idx2], diff_stats)
        # save the figure
        #
        # split the input label strings into multiple lines for better
        # display in case they are too long.
        #
        # 72-point font has one inch height of character. 
        fontsize = 10
        numch_line = int(fig_width*0.6 / (0.5*fontsize/72))

        tmplabel = os.path.basename(infiles[idx1]) + ": " + inds[idx1]
        tmp = len(tmplabel)
        ibeg = np.arange(0, tmp, numch_line, dtype=int)
        iend = ibeg+numch_line
        iend[-1] = tmp
        outlabel1 = "-\n".join([tmplabel[i:j] for i, j in zip(ibeg, iend)])

        tmplabel = os.path.basename(infiles[idx2]) + ": " + inds[idx2]
        tmp = len(tmplabel)
        ibeg = np.arange(0, tmp, numch_line, dtype=int)
        iend = ibeg+numch_line
        iend[-1] = tmp
        outlabel2 = "-\n".join([tmplabel[i:j] for i, j in zip(ibeg, iend)])

        sys.stdout.write("\n")
        print "Output scatter density plot"
        if do_stats:
            fig = plt.figure(figsize=(fig_width, fig_width*1.5))
            ax = plt.subplot2grid((3, 1), (0, 0), rowspan=2)
            ax_diff = plt.subplot2grid((3, 1), (2, 0))
        else:
            fig, ax = plt.subplots(figsize=(fig_width, fig_width))
        
        X, Y = np.meshgrid(hist2d_xed, hist2d_yed)
        # choose color map
        cmap = plt.get_cmap(cmap_name)
        cmap.set_bad(color="#ffffff", alpha=1)
        Z = np.ma.masked_less_equal(final_hist2d_arr, 0)
        Zflag = final_hist2d_arr > 0
        pcm = ax.pcolormesh(X, Y, Z.T, cmap=cmap, edgecolor="none", 
                            vmin=np.percentile(Z[Zflag], 2, interpolation='nearest'), vmax=np.percentile(Z[Zflag], 100-2, interpolation='nearest'))
        ax.set_xlabel(outlabel1, fontsize=fontsize)
        ax.set_ylabel(outlabel2, fontsize=fontsize)
        plt.setp(ax, 
                 xlim=(np.amin(hist2d_xed), np.amax(hist2d_xed)), 
                 ylim=(np.amin(hist2d_yed), np.amax(hist2d_yed)), 
                 aspect="equal")
        divider = make_axes_locatable(ax)
        cax = divider.append_axes("right", size="5%", pad=0.05)
        fig.colorbar(pcm, cax=cax)

        # plot histogram of difference
        if do_stats:
            ax_diff.bar((diffhist_bed[0:-1]+diffhist_bed[1:])*0.5, diff_hist, diffhist_bed[1:]-diffhist_bed[0:-1], 
                         align="center", color="#636363", linewidth=0, edgecolor="none", alpha=1, label="Difference")
            ax_diff.set_xlabel("Variable on X axis - Variable on Y axis", fontsize=fontsize)
            ax_diff.set_ylabel("Frequency")

        plt.tight_layout(h_pad=0.0, w_pad=0.0)
        plt.savefig("{0:s}/scatter_density_{1:s}_vs_{2:s}.png".format(outdir, inlabels[idx1].replace(" ", "_"), inlabels[idx2].replace(" ", "_")), 
                    dpi=dpi, bbox_inches="tight", pad_inches=0)

        print "Output figure of histogram comparison"
        fig, ((ax, cm_ax), (ax_pdf, cm_ax_pdf)) = plt.subplots(2, 2, figsize=(fig_width, fig_width), sharex=True, sharey="row")

        ax.bar((hist1d_bed1[0:-1]+hist1d_bed1[1:])*0.5, final_hist1d_arr1, hist1d_bed1[1:]-hist1d_bed1[0:-1], 
               align="center", color="#e41a1c", linewidth=0, edgecolor="none", alpha=0.4, label=outlabel1)
        ax.bar((hist1d_bed2[0:-1]+hist1d_bed2[1:])*0.5, final_hist1d_arr2, hist1d_bed2[1:]-hist1d_bed2[0:-1], 
               align="center", color="#377eb8", linewidth=0, edgecolor="none", alpha=0.4, label=outlabel2)
        x_lb = np.amin([np.amin(hist1d_bed1), np.amin(hist1d_bed2)])
        x_ub = np.amax([np.amax(hist1d_bed1), np.amax(hist1d_bed2)])
        xlim = (x_lb-(x_ub-x_lb)*0.05, x_ub+(x_ub-x_lb)*0.05)
        plt.setp(ax, xlim=xlim)
        ax.set_xlabel("Valid values of each own", fontsize=fontsize)
        ax.set_ylabel("Frequency", fontsize=fontsize)
        # one more plot of probability density function, i.e. normalized frequency.
        final_hist1d_pdf1 = final_hist1d_arr1 / (hist1d_bed1[1:]-hist1d_bed1[0:-1]) / np.sum(final_hist1d_arr1)
        final_hist1d_pdf2 = final_hist1d_arr2 / (hist1d_bed2[1:]-hist1d_bed2[0:-1]) / np.sum(final_hist1d_arr2)
        ax_pdf.bar((hist1d_bed1[0:-1]+hist1d_bed1[1:])*0.5, final_hist1d_pdf1, hist1d_bed1[1:]-hist1d_bed1[0:-1], 
               align="center", color="#e41a1c", linewidth=0, edgecolor="none", alpha=0.4, label=outlabel1)
        ax_pdf.bar((hist1d_bed2[0:-1]+hist1d_bed2[1:])*0.5, final_hist1d_pdf2, hist1d_bed2[1:]-hist1d_bed2[0:-1], 
               align="center", color="#377eb8", linewidth=0, edgecolor="none", alpha=0.4, label=outlabel2)
        plt.setp(ax_pdf, xlim=xlim)
        ax_pdf.set_xlabel("Valid values of each own", fontsize=fontsize)
        ax_pdf.set_ylabel("Prob. Density", fontsize=fontsize)

        # common valid values
        cm_ax.bar((hist1d_bed1[0:-1]+hist1d_bed1[1:])*0.5, final_cmhist1d_arr1, hist1d_bed1[1:]-hist1d_bed1[0:-1], 
               align="center", color="#e41a1c", linewidth=0, edgecolor="none", alpha=0.4, label=outlabel1)
        cm_ax.bar((hist1d_bed2[0:-1]+hist1d_bed2[1:])*0.5, final_cmhist1d_arr2, hist1d_bed2[1:]-hist1d_bed2[0:-1], 
               align="center", color="#377eb8", linewidth=0, edgecolor="none", alpha=0.4, label=outlabel2)
        x_lb = np.amin([np.amin(hist1d_bed1), np.amin(hist1d_bed2)])
        x_ub = np.amax([np.amax(hist1d_bed1), np.amax(hist1d_bed2)])
        xlim = (x_lb-(x_ub-x_lb)*0.05, x_ub+(x_ub-x_lb)*0.05)
        plt.setp(cm_ax, xlim=xlim)
        cm_ax.set_xlabel("Common valid values", fontsize=fontsize)
        cm_ax.set_ylabel("Frequency", fontsize=fontsize)

        # one more plot of probability density function, i.e. normalized frequency.
        final_cmhist1d_pdf1 = final_cmhist1d_arr1 / (hist1d_bed1[1:]-hist1d_bed1[0:-1]) / np.sum(final_cmhist1d_arr1)
        final_cmhist1d_pdf2 = final_cmhist1d_arr2 / (hist1d_bed2[1:]-hist1d_bed2[0:-1]) / np.sum(final_cmhist1d_arr2)
        cm_ax_pdf.bar((hist1d_bed1[0:-1]+hist1d_bed1[1:])*0.5, final_cmhist1d_pdf1, hist1d_bed1[1:]-hist1d_bed1[0:-1], 
               align="center", color="#e41a1c", linewidth=0, edgecolor="none", alpha=0.4, label=outlabel1)
        cm_ax_pdf.bar((hist1d_bed2[0:-1]+hist1d_bed2[1:])*0.5, final_cmhist1d_pdf2, hist1d_bed2[1:]-hist1d_bed2[0:-1], 
               align="center", color="#377eb8", linewidth=0, edgecolor="none", alpha=0.4, label=outlabel2)
        plt.setp(cm_ax_pdf, xlim=xlim)
        cm_ax_pdf.set_xlabel("Common valid values", fontsize=fontsize)
        cm_ax_pdf.set_ylabel("Prob. Density", fontsize=fontsize)

        ax_pdf.legend(loc="upper center", bbox_to_anchor=(1.0, -0.2), frameon=False, ncol=1, fontsize=fontsize)
        plt.tight_layout()
        plt.savefig("{0:s}/hist_comparison_{1:s}_vs_{2:s}.png".format(outdir, inlabels[idx1].replace(" ", "_"), inlabels[idx2].replace(" ", "_")), 
                    dpi=dpi, bbox_inches="tight", pad_inches=0)

    _ = [fobj.close() for fobj in fobj_list]

    if do_stats:
        if outcsvfile is not None:
            output_obj = open(outcsvfile, "w")
            print colorLogStr("Output statistics of differnce to ") + colorDimStr("{0:s}".format(outcsvfile))
        else:
            output_obj = sys.stdout
            print colorInfoStr("Difference stats: ")

        output_obj.write(outstats_str)

        if outcsvfile is not None:
            output_obj.close()

    print colorResetStr("")
    return

def popcount_func(data, fillv):
    tmpflag = data!=fillv
    data[tmpflag] = [bin(x).count("1") for x in data[tmpflag]]
    return data

if __name__ == "__main__":
    cmdargs = getCmdArgs()
    main(cmdargs)
