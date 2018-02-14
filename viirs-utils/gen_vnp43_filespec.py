#!/usr/bin/env python

import argparse
import datetime
import warnings

import h5py
import numpy as np

import pandas as pd


def getCmdArgs():
    p = argparse.ArgumentParser(description="Generate a file specification file for a VNP43 product according to a predefined filespec template.")
    
    p.add_argument("-t", "--template", dest="filespec_template", required=True, default=None, metavar="FILESPEC_TEMPLATE", help="A predefined template file of file specification.")
    p.add_argument("-f", "--h5f", dest="h5fname", required=True, default=None, metavar="FILE_NAME_OF_SAMPLE_H5_PRODUCT", help="A sample VNP43 H5 product file.")

    p.add_argument("-o", "--output", dest="output", required=True, default=None, metavar="OUTPUT_FILESPEC_FILE", help="File name of the generated file specification.")

    cmdargs = p.parse_args()

    return cmdargs

def interpLine(line, lterm='[', rterm=']'):
# Interpret a line using [keyword] syntax and [[ or ]] to print
# literal [ or ], i.e. escape these two syntax characters. Return a
# list of found keywords and a format string used to print the values
# of keywords in this line.

    lterm_idx = [i for i, ch in enumerate(line) if ch==lterm ]
    rterm_idx = [i for i, ch in enumerate(line) if ch==rterm ]
    if len(lterm_idx) != len(rterm_idx):
        raise RuntimeError(("Syntax error in the filespec template, " 
                            + "keywords miss closing '{0:s}{1:s}' in" 
                            + " the following line:\n{2:s}").format(lterm, rterm, line))

    errmsg = ("Syntax error in the filespec template, " 
              + "keywords miss closing '{0:s}{1:s}' in" 
              + " the following line:\n{2:s}").format(lterm, rterm, line)

    nch = len(line)

    outstr = ""
    keywords = []

    ch_stack=[]
    prev_ch = ""

    kw_potential = 0
    kw_str = ""
    kw_cnt = 0
    for i, ch in enumerate(line):
        if ch == lterm:
            ch_stack.append(ch)

            kw_potential += 1

            if (prev_ch == lterm) and (kw_potential > 1):
                kw_potential -= 2
                # escape this openning
                outstr = outstr + lterm

        elif ch == rterm:
            if not len(ch_stack):
                raise RuntimeError(errmsg)
            else:
                ch_stack_top = ch_stack.pop()
                if ch_stack_top != lterm:
                    raise RuntimeError(errmsg)
                else:
                    if kw_potential > 0:
                        # end of a keyword
                        keywords.append(kw_str)
                        outstr = outstr + "{{{0:d}:s}}".format(kw_cnt)
                        kw_cnt += 1
                        kw_str = ""

                    kw_potential -= 1

                    if (prev_ch == rterm) and (kw_potential < -1):
                        kw_potential += 2
                        # escape this closing
                        outstr = outstr + rterm

        else:
            if kw_potential > 0:
                kw_str = kw_str + ch
            else:
                outstr = outstr + ch

        prev_ch = ch

    return keywords, outstr


def fmtH5TypeValue(val):
    dtype_str = str(type(val)).lower()
    if dtype_str.find("str") > -1:
        return "STRING", "{0:s}".format(val)
    elif dtype_str.find("float") > -1:
        # return "DOUBLE", "{0:.3f}".format(val)
        return dtype_str[dtype_str.find("float"):].rstrip("'>").upper(), "{0:g}".format(val)
    elif dtype_str.find("uint") > -1:
        return dtype_str[dtype_str.find("uint"):].rstrip("'>").upper(), "{0:d}".format(val)
    elif dtype_str.find("int") > -1:
        return dtype_str[dtype_str.find("int"):].rstrip("'>").upper(), "{0:d}".format(val)
    elif dtype_str.find("time") > -1:
        return "DATETIME", str(val).rstrip(" 00:00:00")
    else:
        raise RuntimeError("Unrecognized data type {0:s}".format(str(type(val))))


def getDimList(struct_meta_str, df_name):
    i = struct_meta_str.find(df_name)
    if i > -1:
        j = struct_meta_str[i:].find("DimList")
        k = struct_meta_str[i:][j:].find(")")
        return struct_meta_str[i:][j:][:k].split("=")[1].lstrip("(").split(",")
    else:
        raise RuntimeError("Given Data Field {0:s} not found in the StructMetadata.0".format(df_name))


def attrDictToDataFrame(gattr_dict, const_only=False):
    # These attributes have constant values across product files and
    # their values will be output to the data frame. Otherwise,
    # "Variable" will appear as the value column in the data frame.
    const_attr_names = ["AlgorithmType", "AlgorithmVersion", 
                        "LongName", "PGEVersion", "PGE_Name", 
                        "PlatformShortName", "ProcessingCenter", 
                        "SatelliteInstrument", 
                        "SensorShortname", "ShortName", 
                        "identifier_product_doi_authority"]

    tattr_dict = {}
    for k, val in gattr_dict.iteritems():
        try:
            if str(type(val)).find("str") > -1:
                tval = [val]
            else:
                if len(val) >= 1:
                    tval = val
        except TypeError:
            tval = [val]
        tattr_dict[k] = tval

    for k, val in tattr_dict.iteritems():
        try:
            tval = [pd.to_datetime(v).to_pydatetime() if str(type(v)).find("str")>-1 else v for v in val]
        except ValueError:
            tval = val
        tattr_dict[k] = tval

    out_dict = dict(Name=[], Type=[], Num_Val=[], Source=[], Value=[])
    source_stig = ["AlgorithmType", "AlgorithmVersion", 
                   "EastBoundingCoord", "WestBoundingCoord", 
                   "NorthBoundingCoord", "SouthBoundingCoord"]
    for k in sorted(tattr_dict.keys()):
        out_dict["Name"].append(k)
        val = tattr_dict[k]

        type_str, _ = fmtH5TypeValue(val[0])
        val_str = ",".join([fmtH5TypeValue(v)[1] for v in val])
        if len(val) > 1:
            val_str = "[" + val_str + "]"
        if (not const_only) or (k in const_attr_names):
            out_dict["Value"].append(val_str)
        else:
            out_dict["Value"].append("Variable")
        out_dict["Type"].append(type_str)
        out_dict["Num_Val"].append(len(val))
        if k in source_stig:
            out_dict["Source"].append("STIG")
        else:
            out_dict["Source"].append("PGE")
    out_df = pd.DataFrame(out_dict)[["Name", "Type", "Num_Val", "Source", "Value"]]
    return out_df

def getKeyword(h5fobj, kw):
    if kw == "AlgorithmVersion":
        attr_key = "AlgorithmVersion"
        if attr_key not in h5fobj.attrs.keys():
            warnings.warn("Cannot find '{0:s}' in the global attributes of {1:s}.".format(attr_key, h5fobj.filename), RuntimeWarning)
            return "MISSING"
        return h5fobj.attrs[attr_key].split()[1]

    elif kw == "Date":
        return datetime.datetime.now().strftime("%d %b %Y")

    elif kw == "ShortName":
        attr_key = "ShortName"
        if attr_key not in h5fobj.attrs.keys():
            warnings.warn("Cannot find '{0:s}' in the global attributes of {1:s}.".format(attr_key, h5fobj.filename), RuntimeWarning)
            return "MISSING"
        return h5fobj.attrs[attr_key]

    elif kw == "LongName":
        attr_key = "LongName"
        if attr_key not in h5fobj.attrs.keys():
            warnings.warn("Cannot find '{0:s}' in the global attributes of {1:s}.".format(attr_key, h5fobj.filename), RuntimeWarning)
            return "MISSING"
        return h5fobj.attrs[attr_key]

    elif kw == "Level":
        return '3'

    elif kw == "AlgorithmIdentity":
        attr_key = "AlgorithmVersion"
        if attr_key not in h5fobj.attrs.keys():
            warnings.warn("Cannot find '{0:s}' in the global attributes {1:s}.".format(attr_key, h5fobj.filename), RuntimeWarning)
            return "MISSING"
        return h5fobj.attrs[attr_key].split()[0]

    elif kw == "DataFields":
        df_list = h5fobj['HDFEOS']['GRIDS']['VIIRS_Grid_BRDF']['Data Fields'].keys()
        return "\n".join(df_list)

    elif kw == "GlobalAttributes":
        gattr_dict = dict(h5fobj.attrs.items())
        if "InputPointer" in gattr_dict.keys():
            del gattr_dict["InputPointer"]
            
        out_df = attrDictToDataFrame(gattr_dict, const_only=True)
        
        old_colw = pd.options.display.max_colwidth
        if len(out_df) > 0:
            max_strlen = max([len(row[1].loc["Value"]) for row in out_df.iterrows()]) + 1
            pd.options.display.max_colwidth = max_strlen if max_strlen > old_colw else old_colw

        out_str = out_df.to_string(header=True, index=False, index_names=False, justify="justify")

        pd.options.display.max_colwidth = old_colw

        return out_str

    elif kw == "StructMetadata.0":
        return h5fobj['HDFEOS INFORMATION']['StructMetadata.0'].value

    elif kw == "DataFieldDefinitions":
        out_str_list = []

        for ds_name in h5fobj['HDFEOS']['GRIDS']['VIIRS_Grid_BRDF']['Data Fields'].keys():
            out_str = "\n"

            ds = h5fobj['HDFEOS']['GRIDS']['VIIRS_Grid_BRDF']['Data Fields'][ds_name]

            tmp_df = attrDictToDataFrame(dict(ds.attrs.items()))
            desc_str = ""
            if "Description" in tmp_df["Name"].values:
                row_idx = tmp_df["Name"].values.tolist().index("Description")
                desc_str = tmp_df.loc[row_idx, "Value"]
                tmp_df = tmp_df.drop([0])

            out_str += "SDS Name:\t\t{0:s}\n\n".format(ds_name)
            if "long_name" in ds.attrs.keys():
                out_str += "Description:\t\t{0:s}\n\n".format(ds.attrs['long_name']) 
            else:
                out_str += "Description:\t\t{0:s}\n\n".format(ds_name)
            out_str += desc_str + "\n"
            out_str += "Number Type:\t\t{0:s}\n".format(ds.dtype.name.upper())
            out_str += "Rank:\t\t\t{0:d}\n".format(len(ds.shape))
            out_str += "Dimension Sizes:\t" + ", ".join([str(v) for v in ds.shape]) + "\n"

            dim_list = getDimList(h5fobj['HDFEOS INFORMATION']['StructMetadata.0'].value, ds_name)
            out_str += "Dimension Names:\n" + "\n".join(["\tDimension{0:d}: {1:s}".format(i, v) for i, v in enumerate(dim_list)]) + "\n\n"
            
            out_str += "SDS Attributes:\n"

            old_colw = pd.options.display.max_colwidth
            if len(tmp_df) > 0:
                max_strlen = max([len(row[1].loc["Value"]) for row in tmp_df.iterrows()]) + 1
                pd.options.display.max_colwidth = max_strlen if max_strlen > old_colw else old_colw
            out_str += tmp_df.to_string(header=True, index=False, index_names=False, justify="justify")
            pd.options.display.max_colwidth = old_colw

            out_str += "\n\n"
            out_str_list.append(out_str)

        div_str = "===================================================\n"
        return div_str.join(out_str_list)
    else:
        raise RuntimeError("Unrecognized keyword {0:s} in the file specification template".format(kw))


def main(cmdargs):
    fs_template = cmdargs.filespec_template
    fs_output = cmdargs.output
    h5fname = cmdargs.h5fname

    h5fobj = h5py.File(h5fname, "r")
    with open(fs_template, "r") as fstp_fobj, open(fs_output, "w") as fsout_fobj:
        for line in fstp_fobj:
            keywords, fmtstr = interpLine(line)
            if len(keywords) == 0:
                # No keywords to retrieve value and print
                outstr = line
            else:
                # Retrieve values of keywords and print them in
                # the format string.
                kw_values = []
                for kw in keywords:
                    kw_values.append(getKeyword(h5fobj,  kw))
                outstr = fmtstr.format(*kw_values)
            fsout_fobj.write(outstr)

    h5fobj.close()

if __name__ == "__main__":
    cmdargs = getCmdArgs()
    main(cmdargs)
