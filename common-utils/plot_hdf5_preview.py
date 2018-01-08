#!/usr/bin/env python

# Plot a preview image of a dataset from a HDF-EOS5 file.
# Zhan Li, zhan.li@umb.edu
# Created: Sun Nov  5 17:13:33 EST 2017

import sys
import os
import argparse
import itertools
import warnings

import h5py
import numpy as np

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
    p = argparse.ArgumentParser(description="Plot a preview image of a dataset from an HDF-EOS5 file.")
    
    p.add_argument("--h5f", dest="infile", required=True, nargs="+", default=None, help="Input HDF-EOS5 file, 1 file for single-band image preview or 3 files in the order of RGB bands for RGB composite")
    p.add_argument("--dataset", dest="dataset", required=True, nargs="+", default=None, help="Names of the datasets in the order of the correponding HDF5 files to preview, 1 name or 3 names.")
    p.add_argument("--band", dest="band", required=False, nargs="+", type=int, default=None, help="When a dataset is multiband, e.g. BRDF_Albedo_Parameters, a three-dimensional matrix, this option provides the index to the band to read for each dataset, with the first band as 1. Default: all 1, i.e. the first band.")
    p.add_argument("--of", dest="outfile", required=True, default=None, help="File name of the output preview image.")

    p.add_argument("--stats", dest="stats", required=False, action="store_true", help="If given, generate the following statistics for each dataset, mean, standard deviation, minimum, 5 percentile, 25 percentile, median, 75 percentile, 95 percentile, maximum. If given --ocsv, output the statistics to the CSV file; otherwise, output to stdout.")
    p.add_argument("--attr_keys", dest="attr_keys", required=False, nargs="+", default=None, help="List of attribute names to be searched in each dataset. If an attribute is found, its value is output to the CSV file given by --ocsv, otherwise to stdout. If an attribute is not found, its value will be labeld with N/A in the output.")
    p.add_argument("--ocsv", dest="ocsv", required=False, default=None, help="Name of a CSV file to output the list of metadata attributes for each dataset, and if given --stats, the statistics for each dataset.")

    p.add_argument("--downsample_size", dest="downsample_size", required=False, type=int, default=10, help="Window size to resample input raster for downsampling and preview. Default: 10.")

    p.add_argument("--transform_func", dest="transfunc", required=False, default=None, choices=["popcount"], help="Name of a function to transform pixel values. Choices: ['popcount']. Default: no transformation.")

    p.add_argument("--stretch_min", dest="stretch_min", nargs="+", type=float, required=False, default=None, help="Minimum pixel value for each dataset to be stretched to darkest in the output preview image. Default: all 0")
    p.add_argument("--stretch_max", dest="stretch_max", nargs="+", type=float, required=False, default=None, help="Maximum pixel value for each dataset to be stretched to brightest in the output preview image. Default: all 1000")
    p.add_argument("--background", dest="background_color", nargs=3, type=int, required=False, default=(0, 0, 128), help="RGB values from 0-255 for the background color to render fill values. Default: 0 0 128")

    p.add_argument("--colormap", dest="cmap_name", required=False, default="jet", help="Colormap name for single-band image preview. Availalbe names are from matplotlib library: https://matplotlib.org/users/colormaps.html. Default: jet")
    p.add_argument("--colorbar", dest="colorbar", required=False, action="store_true", help="If set, add a color bar to the output preview image for single-band input.")
    
    p.add_argument("--img_width", dest="img_width", type=float, required=False, default=5, help="Width of output preview image, in inches, the height of an output figure will be automatically adjusted. Default: 5 inches.")

    cmdargs = p.parse_args()

    if len(cmdargs.infile) !=1 and len(cmdargs.infile) != 3:
        raise RuntimeError(colorErrorStr("Number of input files can only be either 1 for single-band image preview or 3 for RGB composite preview."))
    if cmdargs.stretch_min is None:
        cmdargs.stretch_min = (0,)*len(cmdargs.infile)
    if cmdargs.stretch_max is None:
        cmdargs.stretch_max = (1000,)*len(cmdargs.infile)
    if cmdargs.band is None:
        cmdargs.band = (1,)*len(cmdargs.infile)

    if len(cmdargs.dataset) != len(cmdargs.infile):
        raise RuntimeError(colorErrorStr("Numbers of input files and datasets must be equaland one to one."))
    if len(cmdargs.stretch_min) != len(cmdargs.infile):
        raise RuntimeError(colorErrorStr("Numbers of input files and minimum for image stretch must be equaland one to one."))
    if len(cmdargs.stretch_max) != len(cmdargs.infile):
        raise RuntimeError(colorErrorStr("Numbers of input files and maximum for image stretch must be equaland one to one."))
    if len(cmdargs.band) != len(cmdargs.infile):
        raise RuntimeError(colorErrorStr("Numbers of input files and band indexes must be equaland one to one."))

    if (cmdargs.ocsv is not None) and (not cmdargs.stats) and (cmdargs.attr_keys is None):
        raise RuntimeError(colorErrorStr("Neither data stats nor attribute keys are given for writing to the given CSV file."))
    
    return cmdargs

def main(cmdargs):
    infiles = cmdargs.infile
    inds = cmdargs.dataset
    inband = cmdargs.band
    outfile = cmdargs.outfile
    bg_color = cmdargs.background_color
    stretch_min = cmdargs.stretch_min
    stretch_max = cmdargs.stretch_max
    cmap_name = cmdargs.cmap_name
    add_colorbar = cmdargs.colorbar
    img_width = cmdargs.img_width
    dsamp_size = cmdargs.downsample_size
    mem_size = 50e6 # in unit of byte, 50MB memory per image preview
    dpi = 300
    transfunc = cmdargs.transfunc

    do_stats = cmdargs.stats
    outattrkeys = cmdargs.attr_keys
    outcsvfile = cmdargs.ocsv

    nfiles = len(infiles)
    fobj_list = [h5py.File(fname, "r") for fname in infiles]

    dsname_list = [fobj['/'].visit(lambda name: name if ids in name else None) for fobj, ids in itertools.izip(fobj_list, inds)]
    dsname_found = True
    for i, dsname in enumerate(dsname_list):
        if dsname is None:
            print colorErrorStr("Dataset name {0:s} NOT found in {1:s}".format(inds[i], infiles[i]))
            dsname_found = False
    if not dsname_found:
        raise RuntimeError(colorErrorStr("Incorrect dataset name!"))
    
    if outattrkeys is not None:
        print "Extract requested attributes ... "
        outattrvalues_list = [None for fname in infiles]
        for i, (fobj, dsname) in enumerate(itertools.izip(fobj_list, dsname_list)):
            outattrvalues_list[i] = [fobj[dsname].attrs[oak] if oak in fobj[dsname].attrs.keys() else "N/A" for oak in outattrkeys]
            outattrvalues_list[i] = [fobj[dsname].dtype.name] + outattrvalues_list[i]
        outattrkeys = ['dtype'] + outattrkeys

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
            print "{0:s}:{1:s}, no fill value!".format(os.path.basename(infiles[i]), dsname)
    fillvalue_list = [fv if (np.isscalar(fv) or fv is None) else fv[0] for fv in fillvalue_list]
    if np.sum([fv is None for fv in fillvalue_list]) > 0:
        fillvalue_list = [np.iinfo(sds.dtype).max if fv is None else fv for sds, fv in itertools.izip(sds_list, fillvalue_list)]
        warnings.warn(colorWarnStr("Some input datasets miss fill value. Use the maximum values of their data types."), RuntimeWarning)
        print fillvalue_list

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
    # data chunk by chunk.
    # 
    chunk_dsamp_npix_list = [int(np.sqrt(mem_size/sds.dtype.itemsize)/dsamp_size) for sds in sds_list]
    chunk_xsize_list = [dsamp_size*cdn for cdn in chunk_dsamp_npix_list]
    chunk_ysize_list = chunk_xsize_list
    nchunk_x_list = [np.ceil(sds.shape[1]/cx).astype(int) for sds, cx in itertools.izip(sds_list, chunk_xsize_list)]
    nchunk_y_list = [np.ceil(sds.shape[0]/cy).astype(int) for sds, cy in itertools.izip(sds_list, chunk_ysize_list)]
    nchunk_x_list = [ncx if ncx>0 else 1 for ncx in nchunk_x_list]
    nchunk_y_list = [ncy if ncy>0 else 1 for ncy in nchunk_y_list]

    dsamp_xsize_list = [int(np.ceil(sds.shape[1]/dsamp_size)) for sds in sds_list]
    dsamp_ysize_list = [int(np.ceil(sds.shape[0]/dsamp_size)) for sds in sds_list]
    dsamp_img_list = [np.zeros((dy, dx), dtype=sds.dtype) for sds, dx, dy in itertools.izip(sds_list, dsamp_xsize_list, dsamp_ysize_list)]

    if do_stats:
        tmp_x_cnt = np.zeros(len(sds_list))
        tmp_x_sum = np.zeros(len(sds_list))
        tmp_x2_sum = np.zeros(len(sds_list))
        hist_list = [np.zeros(2, dtype=np.int) for sds in sds_list]
        binrange_list = [np.array([0,1], dtype=np.int) for sds in sds_list]
    for i, (sds, cx, ncx, cy, ncy) in enumerate(itertools.izip(sds_list, chunk_xsize_list, nchunk_x_list, chunk_ysize_list, nchunk_y_list)):
        for ix in range(ncx):
            for iy in range(ncy):
                sys.stdout.write("Reading chunk row, col of file {4:d}/{5:d}: {0:d}/{1:d}, {2:d}/{3:d} ... ".format(iy+1, ncy, ix+1, ncx, i+1, nfiles))
                sys.stdout.flush()
                tmpxidx = sds.shape[1] if ix==ncx-1 else (ix+1)*cx
                tmpyidx = sds.shape[0] if iy==ncy-1 else (iy+1)*cy
                if sds.ndim == 2:
                    tmpdata = sds[iy*cy:tmpyidx, ix*cx:tmpxidx]
                elif sds.ndim == 3:
                    tmpdata = sds[iy*cy:tmpyidx, ix*cx:tmpxidx, inband[i]-1]
                else:
                    raise RuntimeError(colorErrorStr("Unexpected number of dimensions of input dataset!"))

                cdn = chunk_dsamp_npix_list[i]
                tmpxidx = dsamp_img_list[i].shape[1] if ix==ncx-1 else (ix+1)*cdn
                tmpyidx = dsamp_img_list[i].shape[0] if iy==ncy-1 else (iy+1)*cdn
                dsamp_img_list[i][iy*cdn:tmpyidx, ix*cdn:tmpxidx] = tmpdata[::dsamp_size, ::dsamp_size]

                if do_stats:
                    sys.stdout.write("Digesting data to estimate data stats ... ")
                    sys.stdout.flush()

                    if transfunc == "popcount":
                        tmpdata = popcount_func(tmpdata, fillvalue_list[i])

                    tmpflag = tmpdata != fillvalue_list[i]
                    tmpdatadbl = tmpdata[tmpflag].astype(np.double)
                    if tmpdatadbl.size==0:
                        sys.stdout.write("\r")
                        continue
                    tmp_x_cnt[i] = tmp_x_cnt[i] + np.sum(tmpflag)
                    tmp_x_sum[i] = tmp_x_sum[i] + np.sum(tmpdatadbl)
                    tmp_x2_sum[i] = tmp_x2_sum[i] + np.sum(tmpdatadbl*tmpdatadbl)

                    tmpmax = np.max(tmpdatadbl)
                    tmpmin = np.min(tmpdatadbl)
                    if tmpmax > binrange_list[i][1]:
                        hist_list[i] = np.append(hist_list[i], np.zeros(int(tmpmax-binrange_list[i][1])))
                        binrange_list[i][1] = tmpmax
                    if tmpmin < binrange_list[i][0]:
                        hist_list[i] = np.append(np.zeros(int(binrange_list[i][0]-tmpmin)), hist_list[i])
                        binrange_list[i][0] = tmpmin
                    tmpbins = np.arange(binrange_list[i][0]-0.5, binrange_list[i][1]+1.5)
                    hist1d_arr, _ = np.histogram(tmpdatadbl, bins=tmpbins)
                    hist_list[i] = hist_list[i] + hist1d_arr

                sys.stdout.write("\r")

    if do_stats:
        # mean, std, min, 5%, 25%, median, 75%, 95%, max
        stats_list = [np.zeros(9) for sds in sds_list]
        pct_list = [0, 5, 25, 50, 75, 95, 100]
        for i, statsvec in enumerate(stats_list):
            statsvec[0] = tmp_x_sum[i] / tmp_x_cnt[i]
            statsvec[1] = np.sqrt(tmp_x2_sum[i] / tmp_x_cnt[i] - statsvec[0]*statsvec[0])
            tmpcs = np.cumsum(hist_list[i]) / float(np.sum(hist_list[i])) * 100
            tmpidx = np.searchsorted(tmpcs, pct_list)
            tmpidx[0], tmpidx[-1] = 0, -1
            statsvec[2:] = np.arange(binrange_list[i][0], binrange_list[i][1]+1)[tmpidx]

    print "\n"
    if transfunc == "popcount":
        print "Transforming the data ..."
        dsamp_img_list = [popcount_func(img, fv) for img, fv in itertools.izip(dsamp_img_list, fillvalue_list)]

    print "Write preview image ..."

    # split the input label strings into multiple lines for better
    # display in case they are too long.
    #
    # 72-point font has one inch height of character. 
    fontsize = 8
    numch_line = int(img_width*0.6 / (0.5*fontsize/72))

    inlabel = ", ".join([os.path.basename(fname) for fname in infiles]) + ": " + ", ".join(inds) # os.path.basename(outfile)
    tmp = len(inlabel)
    ibeg = np.arange(0, tmp, numch_line, dtype=int)
    iend = ibeg+numch_line
    iend[-1] = tmp
    outlabel = "-\n".join([inlabel[i:j] for i, j in zip(ibeg, iend)])

    if len(dsamp_img_list) == 1:
        # single band image to preview in the given colormap.
        fig, ax = plt.subplots(figsize=(img_width, float(img_width)/sds_list[0].shape[1]*sds_list[0].shape[0]))
        # choose color map
        cmap = plt.get_cmap(cmap_name, int(stretch_max[0]-stretch_min[0])+1)
        cmap.set_bad(color=np.array(bg_color)/255., alpha=1)
        img = np.ma.masked_equal(dsamp_img_list[0], fillvalue_list[0])
        ax_im = ax.imshow(img, cmap=cmap, vmin=stretch_min[0], vmax=stretch_max[0], aspect="equal")
        if add_colorbar:
            divider = make_axes_locatable(ax)
            cax = divider.append_axes("right", size="5%", pad=0.05)
            fig.colorbar(ax_im, cax=cax)

        plt.setp(ax, xticks=[], yticks=[])
        ax.set_title(outlabel, fontsize=fontsize)
        plt.savefig(outfile, dpi=dpi, bbox_inches="tight", pad_inches=0.)

    elif len(dsamp_img_list) == 3:
        # alpha_img = reduce(np.logical_and, [img!=fv for img,fv in itertools.izip(dsamp_img_list, fillvalue_list)])
        # alpha_img = alpha_img.astype(np.float)
        fillvalue_rgb = np.array(bg_color)/255.
        for i, (img, smin, smax) in enumerate(itertools.izip(dsamp_img_list, stretch_min, stretch_max)):
            tmp = (img - smin) / float(smax - smin)
            tmp[tmp<0] = 0
            tmp[tmp>1] = 1
            tmp[img==fillvalue_list[i]] = fillvalue_rgb[i] # fillvalue_list[i]
            dsamp_img_list[i] = tmp
        out_img = np.dstack(dsamp_img_list)
        fig, ax = plt.subplots(figsize=(img_width, float(img_width)/sds_list[0].shape[1]*sds_list[0].shape[0]))
        ax.imshow(out_img)
        plt.setp(ax, xticks=[], yticks=[])
        ax.set_title(outlabel, fontsize=fontsize)
        plt.savefig(outfile, dpi=dpi, bbox_inches="tight", pad_inches=0.)
    else:
        raise RuntimeError(colorErrorStr("Number images from input files can only be 1 for single-band image preview or 3 for RGB composite."))

    if do_stats or outattrkeys is not None:
        if outcsvfile is not None:
            print colorLogStr("Write data stats or attribute values to ") + colorDimStr("{0:s}".format(outcsvfile))
            output_obj = open(outcsvfile, "w")
        else:
            print colorInfoStr("Data stats or attribute values: ")
            output_obj = sys.stdout

        headerstr = "file,dataset"
        fmtstr = "{0:s},{1:s}"
        noutvars = 2
        if do_stats:
            headerstr = headerstr + ",mean,std,min,5pct,25pct,median,75pct,95pct,max"
            fmtstr = fmtstr + "," + ",".join(["{{{1:d}[{0:d}]:.3f}}".format(i, noutvars) for i in range(len(stats_list[0]))])
            noutvars = noutvars + 1
        if outattrkeys is not None:
            headerstr = headerstr + ",{0:s}".format(",".join(outattrkeys))
            fmtstr = fmtstr + "," + ",".join(["\"{{{1:d}[{0:d}]:s}}\"".format(i, noutvars) for i in range(len(outattrkeys))])
            noutvars = noutvars + 1

        headerstr = headerstr + "\n"
        fmtstr = fmtstr + "\n"

        output_obj.write(headerstr)
        for i, (fname, dsname) in enumerate(itertools.izip(infiles, dsname_list)):
            outvars = [fname, dsname]
            if do_stats:
                outvars.append(stats_list[i])
            if outattrkeys is not None:
                outvars.append([repr(str(oav)) for oav in outattrvalues_list[i]])
            output_obj.write(fmtstr.format(*outvars))

        if outcsvfile is not None:
            output_obj.close()

    sys.stdout.write(colorResetStr("\n"))

    return

def popcount_func(data, fillv):
    tmpflag = data!=fillv
    data[tmpflag] = [bin(x).count("1") for x in data[tmpflag]]
    return data

if __name__ == "__main__":
    cmdargs = getCmdArgs()
    main(cmdargs)
