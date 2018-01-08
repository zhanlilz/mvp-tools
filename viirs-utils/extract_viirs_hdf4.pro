pro extract_viirs_hdf4, productdir, productid, parnames, lat, lon, year, doy, outfile, $
                        LOCID=locid, TILEMAP3=tilemap3
  compile_opt idl2

  locnum=size(lat, /n_elements)
  if locnum ne size(lon, /n_elements) then begin
     message, 'Input latitudes and longitudes have different numbers of elements!'
     return
  endif

  if not keyword_set(locid) then begin
     locid = indgen(locnum) + 1
  endif
  if locnum ne size(locid, /n_elements) then begin
     message, 'Number of location IDs does not equal to the number of given lat/lon!'
     return
  endif 

  ;; calculate tile id, pixel locations for given lat/lon using MODIS
  ;; tile mapper from
  ;; https://landweb.modaps.eosdis.nasa.gov/developers/tilemap/note.html
  if not keyword_set(tilemap3) then begin
     tilemap3 = '../ext/modis-tilemap3/tilemap3_linux'
  endif 
  tilemap3 = file_expand_path(tilemap3)
  intile = strarr(locnum)
  insam = intarr(locnum)
  inlin = intarr(locnum)
  for i = 0,locnum-1 do begin
     spawn, [tilemap3, 'sn', 'k', 'fwd', 'tp', string(lat[i]), string(lon[i])], tmoutput, /noshell
     tmppos = strpos(tmoutput, 'vert tile')
     tilev = fix(strmid(tmoutput, tmppos+10, 2))
     tmppos = strpos(tmoutput, 'horiz tile')
     tileh = fix(strmid(tmoutput, tmppos+11, 2))
     intile[i] = 'h'+string(tileh, format='(i02)')+'v'+string(tilev, format='(i02)')
     tmppos = strpos(tmoutput, 'line')
     tmpstr = strsplit(strmid(tmoutput, tmppos), /extract)
     insam[i] = round(float(tmpstr[3]))
     inlin[i] = round(float(tmpstr[1]))
  end 

  nsamples = size(year, /n_elements) * size(doy, /n_elements)

  locidout = strarr(nsamples, locnum)
  latout = fltarr(nsamples, locnum)
  lonout = fltarr(nsamples, locnum)
  tileout = strarr(nsamples, locnum)
  samout = intarr(nsamples, locnum)
  linout = intarr(nsamples, locnum)
  foreach loc, locid, idx do begin
     locidout[*, idx] = strtrim(string(loc))
     latout[*, idx] = lat[idx]
     lonout[*, idx] = lon[idx]
     tileout[*, idx] = intile[idx]
     samout[*, idx] = insam[idx]
     linout[*, idx] = inlin[idx]
  end 

  yearout = intarr(nsamples, locnum)
  doyout = intarr(nsamples, locnum)
  outdata = {loc_id:locidout, lat:latout, lon:lonout, tile:tileout, sample:samout, line:linout, year:yearout, doy:doyout}

  parnum = size(parnames, /n_elements)
  partag_begidx = 8

  test_file_found = boolean(0)
  ;; search an exisiting file to check the dimension of each parameter
  foreach year_val, year, year_idx do begin
     if test_file_found then begin
        break
     endif 
     foreach doy_val, doy, doy_idx do begin
        if test_file_found then begin
           break
        endif         
        foreach tile_val, intile, loc_idx do begin
           filenow = FILE_SEARCH(productdir, $
                                 productid + '.A' + string(year_val,format='(i04)') $
                                 + string(doy_val,format='(i03)') + '.' + tile_val + '*.hdf', count=countf)
           if countf le 0 then begin
              continue
           endif else begin
              filenow = filenow[0]
              test_file_found = boolean(1)
              break
           endelse 
        end 
     end 
  end 

  file_id =  HDF_SD_Start(filenow)
  foreach parn, parnames, par_idx do begin
     parnames[par_idx] = strtrim(parn)
     ;; Check the dimension of each parameter data
     parsd_idx = HDF_SD_NameToIndex(file_id, parn)
     ds = HDF_SD_Select(file_id, parsd_idx)
     HDF_SD_GETINFO, ds, ndim=ds_ndim, dims=ds_dims
     if ds_ndim gt 2 then begin
        for i = 0, ds_dims[0]-1 do begin
           outdata = create_struct(outdata, parn + '_' + strtrim(i+1, 2), fltarr(nsamples, locnum)-9999)
        endfor 
     endif else begin
        outdata = create_struct(outdata, parn, fltarr(nsamples, locnum)-9999)
     endelse 
  end 

  print, 'Start reading data'
  sample_idx = 0
  foreach year_val, year, year_idx do begin
     foreach doy_val, doy, doy_idx do begin
        outdata.year[sample_idx, *] = year_val
        outdata.doy[sample_idx, *] = doy_val

        foreach tile_val, intile, loc_idx do begin
           filenow = FILE_SEARCH(productdir, $
                                 productid + '.A' + string(year_val,format='(i04)') $
                                 + string(doy_val,format='(i03)') + '.' + tile_val + '*.hdf', count=countf)

           if countf le 0 then begin
              continue
           endif 
           if countf gt 1 then begin
              print, 'WARNING, more than one product file found, use the first found one!'
           endif 
           filenow = filenow[0]
           print, filenow

           file_id =  HDF_SD_Start(filenow)
           tag_idx = partag_begidx
           foreach parn, parnames, par_idx do begin
              parsd_idx = HDF_SD_NameToIndex(file_id, parn)
              HDF_SD_GetData, HDF_SD_Select(file_id, parsd_idx), pardata
              ;; see if this is a three dimensional data for this
              ;; parameter, such as BRDF_Albedo_Parameters_shortwave
              pardata_ndim = size(pardata, /n_dimensions)
              if pardata_ndim gt 2 then begin
                 pardata_nsubp = (size(pardata, /dimensions))[0]
                 for i=0, pardata_nsubp-1 do begin
                    outdata.(tag_idx)[sample_idx, loc_idx] = pardata[i, insam[loc_idx], inlin[loc_idx]]
                    tag_idx = tag_idx + 1
                 endfor 
              endif else begin
                 outdata.(tag_idx)[sample_idx, loc_idx] = pardata[insam[loc_idx], inlin[loc_idx]]
                 tag_idx = tag_idx + 1
              endelse 
           end 
           HDF_SD_END,file_id
        end 
        sample_idx = sample_idx + 1
     end 
  end 

  outdatatags = tag_names(outdata)
  write_csv, outfile, outdata, HEADER=outdatatags

end
