pro mod08_to_diff_ratio, mod08dir, lat, lon, year, doy, time, outfile, UTC=utc, LUTFILE=lutfile, LOCID=locid
  ;; ***************** input *************************** 
  ;; 
  ;; mod08dir: the folder to MOD08 files. Under this folder, MOD08
  ;; files are put in subfolders of years.
  ;; 
  ;; lat, lon: 1D array of float, list of latitudes and longitudes
  ;;
  ;; year: 1D array of integers, list of years
  ;;
  ;; doy: 1D array of integers, list of DOYs
  ;;
  ;; time: 1D array of float, list of time, 0 through 2400, e.g. a
  ;; value of 1430.0 represents a time of 14:30
  ;;
  ;; UTC: keyword, if set, the time given is UTC time. Otherwise, the
  ;; given time is geographically local time, NOT the local time
  ;; governed by administrative areas or daylight saving time.
  ;;
  ;; ***************************************************

  compile_opt idl2
  RESOLVE_ALL

  ;; some default setting for MOD08 AOD data
  scale_factor = 0.0010000000474974513
  add_offset = 0.0
  
  if not keyword_set(lutfile) then begin
     lutfile = '../data/skyl_lut-IDL.dat'
  endif
  lutfile = FILE_EXPAND_PATH(lutfile)
  print, 'Using LUT file: ' + lutfile
  ;; ***Read LUT data***[2]TYPE*[10]BANDS*[90]SZN*[50]AOP***
  LUT_sky=MAKE_ARRAY(50,1800,/FLOAT)
  openr,lun,lutfile,/get_lun
  readf,lun,LUT_sky
  FREE_LUN, lun
  LUT4D=MAKE_ARRAY(50,90,10,2,/FLOAT)
  FOR T=0,1 DO BEGIN     
     FOR B=0,9 DO BEGIN
        LUT4D[*,*,B,T]=LUT_sky[*,T*900+B*90:T*900+(B+1)*90-1]
     END
  END
  ;; end of reading LUT data 

  ;; ************out data *******************
  sitenum = size(lat, /n_elements)
  if sitenum ne size(lon, /n_elements) then begin
     message, 'Input lat and lon have different numbers of elements!'
     return
  endif 
  if not keyword_set(locid) then begin
     locid = indgen(sitenum)+1
  endif 
  nlines = size(year, /n_elements) * size(doy, /n_elements) * size(time, /n_elements)
  latout = fltarr(sitenum, nlines)
  lonout = fltarr(sitenum, nlines)
  locidout = strarr(sitenum, nlines)
  for i = 0,sitenum-1 do begin
     latout[i, *] = lat[i]
     lonout[i, *] = lon[i]
     locidout[i, *] = strtrim(string(locid[i]))
  end 
  yearout = intarr(sitenum, nlines, /nozero)
  doyout = intarr(sitenum, nlines, /nozero)
  local_timeout = fltarr(sitenum, nlines, /nozero)
  utcout = fltarr(sitenum, nlines, /nozero)
  sznout = fltarr(sitenum, nlines, /nozero)
  sazout = fltarr(sitenum, nlines, /nozero)
  mod08_aodout = fltarr(sitenum, nlines) - 9999
  mod08_aod_qaout = intarr(sitenum, nlines) - 9999 ;; 0 good, 1 bad
  skyp_out = fltarr(sitenum, nlines) - 9999 ;; this is diff_ratio

  ;; calculate the offset time, utc + offset = local time
  timenum = size(time, /n_elements)
  offset_hours = fltarr(sitenum, timenum)
  for i = 0,timenum-1 do begin
     offset_hours[*, i] = (lon / 15.0)
  end 
  ;; convert floating time values to hour values
  tmptime = fltarr(sitenum, timenum)
  time_in_hours = fltarr(sitenum, timenum)
  for i = 0,sitenum-1 do begin
     time_in_hours[i, *] = time2hour(time)
     tmptime[i, *] = time
  end
  if keyword_set(utc) then begin
     tmputc = tmptime
     tmplocal = hour2time(time_in_hours + offset_hours)
  endif else begin
     tmputc = hour2time(time_in_hours - offset_hours)
     tmplocal = tmptime
  endelse

  line_idx = 0
  ;; calculate julian day
  jd = dblarr(sitenum, nlines, /nozero)
  foreach year_val, year, year_idx do begin
     foreach doy_val, doy, doy_idx do begin
        foreach time_val, time, time_idx do begin
           yearout[*, line_idx] = year_val
           doyout[*, line_idx] = doy_val
           utcout[*, line_idx] = tmputc[*, time_idx]
           local_timeout[*, line_idx] = tmplocal[*, time_idx]

           for i = 0,sitenum-1 do begin
              hms = time2hms(utcout[i, line_idx])
              jd[i, line_idx] = date_conv([year_val, doy_val, hms[0], hms[1], hms[2]], 'JULIAN')
           end 

           line_idx = line_idx + 1
        end 
     end 
  end
  ;; calculate solar angles
  for i = 0,sitenum-1 do begin
     sunpos, jd[i, *], ra, dec
     eq2hor, ra, dec, jd[i, *], alt, az, LAT=lat[i], LON=lon[i]
     sznout[i, *] = 90.0 - alt
     sazout[i, *] = az
  end 

  TD=0
  BD=9
  latL=FLOOR(ABS(lat-90))
  lonL=FLOOR(ABS(lon-(-180)))
  print, 'Start reading MOD08'
  foreach year_val, year, year_idx do begin
     foreach doy_val, doy, doy_idx do begin
        M8_file_s = FILE_SEARCH(mod08dir+path_sep()+string(year_val,format='(i04)')+path_sep()+'MOD08_D3.A'+string(year_val,format='(i04)')+string(doy_val,format='(i03)')+'*.hdf', COUNT=count8)
        M8_file = M8_file_s[0]
        print, M8_file
        
        if file_test(M8_file) then begin
           file8_id =  HDF_SD_Start(M8_file)
           AOD_index = HDF_SD_NameToIndex(file8_id, 'AOD_550_Dark_Target_Deep_Blue_Combined_Mean')
           AODID = HDF_SD_Select(file8_id, AOD_index)
           HDF_SD_GetData, AODID, AODDATA
           HDF_SD_END,file8_id

           ;; find output lines of this year and doy
           line_indices = where((yearout[0, *] eq year_val) * (doyout[0, *] eq doy_val))

           AODN=AODDATA[lonL,latL]*scale_factor+add_offset
           aod_fill_indices = where((AODN Lt 0.0)+(AODN Gt 1.0))
           AODN[aod_fill_indices] = 0.2
           mod08_aod_qaout[*, line_indices] = 0
           foreach idx, aod_fill_indices do begin
              mod08_aod_qaout[idx, line_indices] = 1
           end 
           foreach idx, line_indices do begin
              mod08_aodout[*, idx] = AODN
           end 
        endif 
     end
  end
  print, 'Finish reading MOD08'
  
  tmp = LUT4D[*, *, BD, TD]
  for i = 0,sitenum-1 do begin
     line_indices = where(mod08_aodout[i, *] ne -9999)
     SD = floor(sznout[i, line_indices])
     AD = floor(mod08_aodout[i, line_indices]*50)
     skyp_out[i, line_indices] = tmp[AD, SD]
  end 

  outdata = {loc_id:(transpose(locidout))[*], $
             lat:(transpose(latout))[*], $
             lon:(transpose(lonout))[*], $
             year:fix((transpose(yearout))[*]), $
             doy:fix((transpose(doyout))[*]), $
             local_time:(transpose(local_timeout))[*], $
             utc:(transpose(utcout))[*], $
             szn:(transpose(sznout))[*], $
             saz:(transpose(sazout))[*], $
             mod08_aod:(transpose(mod08_aodout))[*], $
             mod08_aod_qa:fix((transpose(mod08_aod_qaout))[*]), $
             diff_ratio:(transpose(skyp_out))[*]}

  write_csv, outfile, outdata, HEADER=tag_names(outdata)

end

function hour2time, hour
;; convert floating value of hours into floating time like 1330.2 as
;; 13:30.2
  return, floor(hour)*100 + (hour - floor(hour))*60
end

function time2hour, time
;; convert floating time like 1330.2 as 13:30.2 to floating value of
;; hours. 
  return, floor(time/100) + (time - floor(time/100)*100)/60.0
end

function time2hms, time
;; convert floating time like 1330.2 as 13:30.2 to 3-element vector of
;; hour, minute, and second
  hour = floor(time/100)
  tmp = time - hour*100
  minute = floor(tmp)
  second = (tmp - minute) * 60
  return, [hour, minute, second]
end
