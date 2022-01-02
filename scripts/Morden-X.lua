-- mpv-osc-morden by maoiscat
-- email:valarmor@163.com
-- https://github.com/maoiscat/mpv-osc-morden

-- fork by cyl0
-- https://github.com/cyl0/mpv-osc-morden-x

-- forked again by dexeonify
-- https://github.com/dexeonify/mpv-config/blob/main/scripts/modernx.lua

--[[
    Copyright (C) 2017 AMM

    This program is free software: you can redistribute it and/or modify
    it under the terms of the GNU General Public License as published by
    the Free Software Foundation, either version 3 of the License, or
    (at your option) any later version.

    This program is distributed in the hope that it will be useful,
    but WITHOUT ANY WARRANTY; without even the implied warranty of
    MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
    GNU General Public License for more details.

    You should have received a copy of the GNU General Public License
    along with this program.  If not, see <http://www.gnu.org/licenses/>.
]]--
--[[
    mpv_thumbnail_script.lua 0.4.4 - commit ddb8b1d (branch master)
    https://github.com/TheAMM/mpv_thumbnail_script
    Built on 2022-01-01 10:47:04
]]--
local assdraw = require 'mp.assdraw'
local msg = require 'mp.msg'
local opt = require 'mp.options'
local utils = require 'mp.utils'

-- Determine platform --
ON_WINDOWS = (package.config:sub(1,1) ~= '/')

-- Some helper functions needed to parse the options --
function isempty(v) return (v == false) or (v == nil) or (v == "") or (v == 0) or (type(v) == "table" and next(v) == nil) end

function divmod (a, b)
  return math.floor(a / b), a % b
end

-- Better modulo
function bmod( i, N )
  return (i % N + N) % N
end

function join_paths(...)
  local sep = ON_WINDOWS and "\\" or "/"
  local result = "";
  for i, p in pairs({...}) do
    if p ~= "" then
      if is_absolute_path(p) then
        result = p
      else
        result = (result ~= "") and (result:gsub("[\\"..sep.."]*$", "") .. sep .. p) or p
      end
    end
  end
  return result:gsub("[\\"..sep.."]*$", "")
end

-- /some/path/file.ext -> /some/path, file.ext
function split_path( path )
  local sep = ON_WINDOWS and "\\" or "/"
  local first_index, last_index = path:find('^.*' .. sep)

  if last_index == nil then
    return "", path
  else
    local dir = path:sub(0, last_index-1)
    local file = path:sub(last_index+1, -1)

    return dir, file
  end
end

function is_absolute_path( path )
  local tmp, is_win  = path:gsub("^[A-Z]:\\", "")
  local tmp, is_unix = path:gsub("^/", "")
  return (is_win > 0) or (is_unix > 0)
end

function Set(source)
  local set = {}
  for _, l in ipairs(source) do set[l] = true end
  return set
end

---------------------------
-- More helper functions --
---------------------------

-- Removes all keys from a table, without destroying the reference to it
function clear_table(target)
  for key, value in pairs(target) do
    target[key] = nil
  end
end
function shallow_copy(target)
  local copy = {}
  for k, v in pairs(target) do
    copy[k] = v
  end
  return copy
end

-- Rounds to given decimals. eg. round_dec(3.145, 0) => 3
function round_dec(num, idp)
  local mult = 10^(idp or 0)
  return math.floor(num * mult + 0.5) / mult
end

function file_exists(name)
  local f = io.open(name, "rb")
  if f ~= nil then
    local ok, err, code = f:read(1)
    io.close(f)
    return code == nil
  else
    return false
  end
end

function path_exists(name)
  local f = io.open(name, "rb")
  if f ~= nil then
    io.close(f)
    return true
  else
    return false
  end
end

function create_directories(path)
  local cmd
  if ON_WINDOWS then
    cmd = { args = {"cmd", "/c", "mkdir", path} }
  else
    cmd = { args = {"mkdir", "-p", path} }
  end
  utils.subprocess(cmd)
end

-- Find an executable in PATH or CWD with the given name
function find_executable(name)
  local delim = ON_WINDOWS and ";" or ":"

  local pwd = os.getenv("PWD") or utils.getcwd()
  local path = os.getenv("PATH")

  local env_path = pwd .. delim .. path -- Check CWD first

  local result, filename
  for path_dir in env_path:gmatch("[^"..delim.."]+") do
    filename = join_paths(path_dir, name)
    if file_exists(filename) then
      result = filename
      break
    end
  end

  return result
end

local ExecutableFinder = { path_cache = {} }
-- Searches for an executable and caches the result if any
function ExecutableFinder:get_executable_path( name, raw_name )
  name = ON_WINDOWS and not raw_name and (name .. ".exe") or name

  if self.path_cache[name] == nil then
    self.path_cache[name] = find_executable(name) or false
  end
  return self.path_cache[name]
end

-- Format seconds to HH.MM.SS.sss
function format_time(seconds, sep, decimals)
  decimals = decimals == nil and 3 or decimals
  sep = sep and sep or "."
  local s = seconds
  local h, s = divmod(s, 60*60)
  local m, s = divmod(s, 60)

  local second_format = string.format("%%0%d.%df", 2+(decimals > 0 and decimals+1 or 0), decimals)

  return string.format("%02d"..sep.."%02d"..sep..second_format, h, m, s)
end

-- Format seconds to 1h 2m 3.4s
function format_time_hms(seconds, sep, decimals, force_full)
  decimals = decimals == nil and 1 or decimals
  sep = sep ~= nil and sep or " "

  local s = seconds
  local h, s = divmod(s, 60*60)
  local m, s = divmod(s, 60)

  if force_full or h > 0 then
    return string.format("%dh"..sep.."%dm"..sep.."%." .. tostring(decimals) .. "fs", h, m, s)
  elseif m > 0 then
    return string.format("%dm"..sep.."%." .. tostring(decimals) .. "fs", m, s)
  else
    return string.format("%." .. tostring(decimals) .. "fs", s)
  end
end

-- Writes text on OSD and console
function log_info(txt, timeout)
  timeout = timeout or 1.5
  msg.info(txt)
  mp.osd_message(txt, timeout)
end

-- Join table items, ala ({"a", "b", "c"}, "=", "-", ", ") => "=a-, =b-, =c-"
function join_table(source, before, after, sep)
  before = before or ""
  after = after or ""
  sep = sep or ", "
  local result = ""
  for i, v in pairs(source) do
    if not isempty(v) then
      local part = before .. v .. after
      if i == 1 then
        result = part
      else
        result = result .. sep .. part
      end
    end
  end
  return result
end

function wrap(s, char)
  char = char or "'"
  return char .. s .. char
end
-- Wraps given string into 'string' and escapes any 's in it
function escape_and_wrap(s, char, replacement)
  char = char or "'"
  replacement = replacement or "\\" .. char
  return wrap(string.gsub(s, char, replacement), char)
end
-- Escapes single quotes in a string and wraps the input in single quotes
function escape_single_bash(s)
  return escape_and_wrap(s, "'", "'\\''")
end

-- Returns (a .. b) if b is not empty or nil
function joined_or_nil(a, b)
  return not isempty(b) and (a .. b) or nil
end

-- Put items from one table into another
function extend_table(target, source)
  for i, v in pairs(source) do
    table.insert(target, v)
  end
end

-- Creates a handle and filename for a temporary random file (in current directory)
function create_temporary_file(base, mode, suffix)
  local handle, filename
  suffix = suffix or ""
  while true do
    filename = base .. tostring(math.random(1, 5000)) .. suffix
    handle = io.open(filename, "r")
    if not handle then
      handle = io.open(filename, mode)
      break
    end
    io.close(handle)
  end
  return handle, filename
end


function get_processor_count()
  local proc_count

  if ON_WINDOWS then
    proc_count = tonumber(os.getenv("NUMBER_OF_PROCESSORS"))
  else
    local cpuinfo_handle = io.open("/proc/cpuinfo")
    if cpuinfo_handle ~= nil then
      local cpuinfo_contents = cpuinfo_handle:read("*a")
      local _, replace_count = cpuinfo_contents:gsub('processor', '')
      proc_count = replace_count
    end
  end

  if proc_count and proc_count > 0 then
      return proc_count
  else
    return nil
  end
end

function substitute_values(string, values)
  local substitutor = function(match)
    if match == "%" then
       return "%"
    else
      -- nil is discarded by gsub
      return values[match]
    end
  end

  local substituted = string:gsub('%%(.)', substitutor)
  return substituted
end

-- ASS HELPERS --
function round_rect_top( ass, x0, y0, x1, y1, r )
  local c = 0.551915024494 * r -- circle approximation
  ass:move_to(x0 + r, y0)
  ass:line_to(x1 - r, y0) -- top line
  if r > 0 then
      ass:bezier_curve(x1 - r + c, y0, x1, y0 + r - c, x1, y0 + r) -- top right corner
  end
  ass:line_to(x1, y1) -- right line
  ass:line_to(x0, y1) -- bottom line
  ass:line_to(x0, y0 + r) -- left line
  if r > 0 then
      ass:bezier_curve(x0, y0 + r - c, x0 + r - c, y0, x0 + r, y0) -- top left corner
  end
end

function round_rect(ass, x0, y0, x1, y1, rtl, rtr, rbr, rbl)
    local c = 0.551915024494
    ass:move_to(x0 + rtl, y0)
    ass:line_to(x1 - rtr, y0) -- top line
    if rtr > 0 then
        ass:bezier_curve(x1 - rtr + rtr*c, y0, x1, y0 + rtr - rtr*c, x1, y0 + rtr) -- top right corner
    end
    ass:line_to(x1, y1 - rbr) -- right line
    if rbr > 0 then
        ass:bezier_curve(x1, y1 - rbr + rbr*c, x1 - rbr + rbr*c, y1, x1 - rbr, y1) -- bottom right corner
    end
    ass:line_to(x0 + rbl, y1) -- bottom line
    if rbl > 0 then
        ass:bezier_curve(x0 + rbl - rbl*c, y1, x0, y1 - rbl + rbl*c, x0, y1 - rbl) -- bottom left corner
    end
    ass:line_to(x0, y0 + rtl) -- left line
    if rtl > 0 then
        ass:bezier_curve(x0, y0 + rtl - rtl*c, x0 + rtl - rtl*c, y0, x0 + rtl, y0) -- top left corner
    end
end
-- $Revision: 1.5 $
-- $Date: 2014-09-10 16:54:25 $

-- This module was originally taken from http://cube3d.de/uploads/Main/sha1.txt.

-------------------------------------------------------------------------------
-- SHA-1 secure hash computation, and HMAC-SHA1 signature computation,
-- in pure Lua (tested on Lua 5.1)
-- License: MIT
--
-- Usage:
-- local hashAsHex = sha1.hex(message) -- returns a hex string
-- local hashAsData = sha1.bin(message) -- returns raw bytes
--
-- local hmacAsHex = sha1.hmacHex(key, message) -- hex string
-- local hmacAsData = sha1.hmacBin(key, message) -- raw bytes
--
--
-- Pass sha1.hex() a string, and it returns a hash as a 40-character hex string.
-- For example, the call
--
-- local hash = sha1.hex("iNTERFACEWARE")
--
-- puts the 40-character string
--
-- "e76705ffb88a291a0d2f9710a5471936791b4819"
--
-- into the variable 'hash'
--
-- Pass sha1.hmacHex() a key and a message, and it returns the signature as a
-- 40-byte hex string.
--
--
-- The two "bin" versions do the same, but return the 20-byte string of raw
-- data that the 40-byte hex strings represent.
--
-------------------------------------------------------------------------------
--
-- Description
-- Due to the lack of bitwise operations in 5.1, this version uses numbers to
-- represents the 32bit words that we combine with binary operations. The basic
-- operations of byte based "xor", "or", "and" are all cached in a combination
-- table (several 64k large tables are built on startup, which
-- consumes some memory and time). The caching can be switched off through
-- setting the local cfg_caching variable to false.
-- For all binary operations, the 32 bit numbers are split into 8 bit values
-- that are combined and then merged again.
--
-- Algorithm: http://www.itl.nist.gov/fipspubs/fip180-1.htm
--
-------------------------------------------------------------------------------

local sha1 = (function()
local sha1 = {}

-- set this to false if you don't want to build several 64k sized tables when
-- loading this file (takes a while but grants a boost of factor 13)
local cfg_caching = false
-- local storing of global functions (minor speedup)
local floor,modf = math.floor,math.modf
local char,format,rep = string.char,string.format,string.rep

-- merge 4 bytes to an 32 bit word
local function bytes_to_w32 (a,b,c,d) return a*0x1000000+b*0x10000+c*0x100+d end
-- split a 32 bit word into four 8 bit numbers
local function w32_to_bytes (i)
   return floor(i/0x1000000)%0x100,floor(i/0x10000)%0x100,floor(i/0x100)%0x100,i%0x100
end

-- shift the bits of a 32 bit word. Don't use negative values for "bits"
local function w32_rot (bits,a)
   local b2 = 2^(32-bits)
   local a,b = modf(a/b2)
   return a+b*b2*(2^(bits))
end

-- caching function for functions that accept 2 arguments, both of values between
-- 0 and 255. The function to be cached is passed, all values are calculated
-- during loading and a function is returned that returns the cached values (only)
local function cache2arg (fn)
   if not cfg_caching then return fn end
   local lut = {}
   for i=0,0xffff do
      local a,b = floor(i/0x100),i%0x100
      lut[i] = fn(a,b)
   end
   return function (a,b)
      return lut[a*0x100+b]
   end
end

-- splits an 8-bit number into 8 bits, returning all 8 bits as booleans
local function byte_to_bits (b)
   local b = function (n)
      local b = floor(b/n)
      return b%2==1
   end
   return b(1),b(2),b(4),b(8),b(16),b(32),b(64),b(128)
end

-- builds an 8bit number from 8 booleans
local function bits_to_byte (a,b,c,d,e,f,g,h)
   local function n(b,x) return b and x or 0 end
   return n(a,1)+n(b,2)+n(c,4)+n(d,8)+n(e,16)+n(f,32)+n(g,64)+n(h,128)
end

-- debug function for visualizing bits in a string
local function bits_to_string (a,b,c,d,e,f,g,h)
   local function x(b) return b and "1" or "0" end
   return ("%s%s%s%s %s%s%s%s"):format(x(a),x(b),x(c),x(d),x(e),x(f),x(g),x(h))
end

-- debug function for converting a 8-bit number as bit string
local function byte_to_bit_string (b)
   return bits_to_string(byte_to_bits(b))
end

-- debug function for converting a 32 bit number as bit string
local function w32_to_bit_string(a)
   if type(a) == "string" then return a end
   local aa,ab,ac,ad = w32_to_bytes(a)
   local s = byte_to_bit_string
   return ("%s %s %s %s"):format(s(aa):reverse(),s(ab):reverse(),s(ac):reverse(),s(ad):reverse()):reverse()
end

-- bitwise "and" function for 2 8bit number
local band = cache2arg (function(a,b)
      local A,B,C,D,E,F,G,H = byte_to_bits(b)
      local a,b,c,d,e,f,g,h = byte_to_bits(a)
      return bits_to_byte(
         A and a, B and b, C and c, D and d,
         E and e, F and f, G and g, H and h)
   end)

-- bitwise "or" function for 2 8bit numbers
local bor = cache2arg(function(a,b)
      local A,B,C,D,E,F,G,H = byte_to_bits(b)
      local a,b,c,d,e,f,g,h = byte_to_bits(a)
      return bits_to_byte(
         A or a, B or b, C or c, D or d,
         E or e, F or f, G or g, H or h)
   end)

-- bitwise "xor" function for 2 8bit numbers
local bxor = cache2arg(function(a,b)
      local A,B,C,D,E,F,G,H = byte_to_bits(b)
      local a,b,c,d,e,f,g,h = byte_to_bits(a)
      return bits_to_byte(
         A ~= a, B ~= b, C ~= c, D ~= d,
         E ~= e, F ~= f, G ~= g, H ~= h)
   end)

-- bitwise complement for one 8bit number
local function bnot (x)
   return 255-(x % 256)
end

-- creates a function to combine to 32bit numbers using an 8bit combination function
local function w32_comb(fn)
   return function (a,b)
      local aa,ab,ac,ad = w32_to_bytes(a)
      local ba,bb,bc,bd = w32_to_bytes(b)
      return bytes_to_w32(fn(aa,ba),fn(ab,bb),fn(ac,bc),fn(ad,bd))
   end
end

-- create functions for and, xor and or, all for 2 32bit numbers
local w32_and = w32_comb(band)
local w32_xor = w32_comb(bxor)
local w32_or = w32_comb(bor)

-- xor function that may receive a variable number of arguments
local function w32_xor_n (a,...)
   local aa,ab,ac,ad = w32_to_bytes(a)
   for i=1,select('#',...) do
      local ba,bb,bc,bd = w32_to_bytes(select(i,...))
      aa,ab,ac,ad = bxor(aa,ba),bxor(ab,bb),bxor(ac,bc),bxor(ad,bd)
   end
   return bytes_to_w32(aa,ab,ac,ad)
end

-- combining 3 32bit numbers through binary "or" operation
local function w32_or3 (a,b,c)
   local aa,ab,ac,ad = w32_to_bytes(a)
   local ba,bb,bc,bd = w32_to_bytes(b)
   local ca,cb,cc,cd = w32_to_bytes(c)
   return bytes_to_w32(
      bor(aa,bor(ba,ca)), bor(ab,bor(bb,cb)), bor(ac,bor(bc,cc)), bor(ad,bor(bd,cd))
   )
end

-- binary complement for 32bit numbers
local function w32_not (a)
   return 4294967295-(a % 4294967296)
end

-- adding 2 32bit numbers, cutting off the remainder on 33th bit
local function w32_add (a,b) return (a+b) % 4294967296 end

-- adding n 32bit numbers, cutting off the remainder (again)
local function w32_add_n (a,...)
   for i=1,select('#',...) do
      a = (a+select(i,...)) % 4294967296
   end
   return a
end
-- converting the number to a hexadecimal string
local function w32_to_hexstring (w) return format("%08x",w) end

-- calculating the SHA1 for some text
function sha1.hex(msg)
   local H0,H1,H2,H3,H4 = 0x67452301,0xEFCDAB89,0x98BADCFE,0x10325476,0xC3D2E1F0
   local msg_len_in_bits = #msg * 8

   local first_append = char(0x80) -- append a '1' bit plus seven '0' bits

   local non_zero_message_bytes = #msg +1 +8 -- the +1 is the appended bit 1, the +8 are for the final appended length
   local current_mod = non_zero_message_bytes % 64
   local second_append = current_mod>0 and rep(char(0), 64 - current_mod) or ""

   -- now to append the length as a 64-bit number.
   local B1, R1 = modf(msg_len_in_bits / 0x01000000)
   local B2, R2 = modf( 0x01000000 * R1 / 0x00010000)
   local B3, R3 = modf( 0x00010000 * R2 / 0x00000100)
   local B4 = 0x00000100 * R3

   local L64 = char( 0) .. char( 0) .. char( 0) .. char( 0) -- high 32 bits
   .. char(B1) .. char(B2) .. char(B3) .. char(B4) -- low 32 bits

   msg = msg .. first_append .. second_append .. L64

   assert(#msg % 64 == 0)

   local chunks = #msg / 64

   local W = { }
   local start, A, B, C, D, E, f, K, TEMP
   local chunk = 0

   while chunk < chunks do
      --
      -- break chunk up into W[0] through W[15]
      --
      start,chunk = chunk * 64 + 1,chunk + 1

      for t = 0, 15 do
         W[t] = bytes_to_w32(msg:byte(start, start + 3))
         start = start + 4
      end

      --
      -- build W[16] through W[79]
      --
      for t = 16, 79 do
         -- For t = 16 to 79 let Wt = S1(Wt-3 XOR Wt-8 XOR Wt-14 XOR Wt-16).
         W[t] = w32_rot(1, w32_xor_n(W[t-3], W[t-8], W[t-14], W[t-16]))
      end

      A,B,C,D,E = H0,H1,H2,H3,H4

      for t = 0, 79 do
         if t <= 19 then
            -- (B AND C) OR ((NOT B) AND D)
            f = w32_or(w32_and(B, C), w32_and(w32_not(B), D))
            K = 0x5A827999
         elseif t <= 39 then
            -- B XOR C XOR D
            f = w32_xor_n(B, C, D)
            K = 0x6ED9EBA1
         elseif t <= 59 then
            -- (B AND C) OR (B AND D) OR (C AND D
            f = w32_or3(w32_and(B, C), w32_and(B, D), w32_and(C, D))
            K = 0x8F1BBCDC
         else
            -- B XOR C XOR D
            f = w32_xor_n(B, C, D)
            K = 0xCA62C1D6
         end

         -- TEMP = S5(A) + ft(B,C,D) + E + Wt + Kt;
         A,B,C,D,E = w32_add_n(w32_rot(5, A), f, E, W[t], K),
         A, w32_rot(30, B), C, D
      end
      -- Let H0 = H0 + A, H1 = H1 + B, H2 = H2 + C, H3 = H3 + D, H4 = H4 + E.
      H0,H1,H2,H3,H4 = w32_add(H0, A),w32_add(H1, B),w32_add(H2, C),w32_add(H3, D),w32_add(H4, E)
   end
   local f = w32_to_hexstring
   return f(H0) .. f(H1) .. f(H2) .. f(H3) .. f(H4)
end

local function hex_to_binary(hex)
   return hex:gsub('..', function(hexval)
         return string.char(tonumber(hexval, 16))
      end)
end

function sha1.bin(msg)
   return hex_to_binary(sha1.hex(msg))
end

local xor_with_0x5c = {}
local xor_with_0x36 = {}
-- building the lookuptables ahead of time (instead of littering the source code
-- with precalculated values)
for i=0,0xff do
   xor_with_0x5c[char(i)] = char(bxor(i,0x5c))
   xor_with_0x36[char(i)] = char(bxor(i,0x36))
end

local blocksize = 64 -- 512 bits

function sha1.hmacHex(key, text)
   assert(type(key) == 'string', "key passed to hmacHex should be a string")
   assert(type(text) == 'string', "text passed to hmacHex should be a string")

   if #key > blocksize then
      key = sha1.bin(key)
   end

   local key_xord_with_0x36 = key:gsub('.', xor_with_0x36) .. string.rep(string.char(0x36), blocksize - #key)
   local key_xord_with_0x5c = key:gsub('.', xor_with_0x5c) .. string.rep(string.char(0x5c), blocksize - #key)

   return sha1.hex(key_xord_with_0x5c .. sha1.bin(key_xord_with_0x36 .. text))
end

function sha1.hmacBin(key, text)
   return hex_to_binary(sha1.hmacHex(key, text))
end

return sha1
end)()

local SCRIPT_NAME = "mpv_thumbnail_script"

local default_cache_base = ON_WINDOWS and os.getenv("TEMP") or "/tmp/"

local thumbnailer_options = {
    -- The thumbnail directory
    cache_directory = join_paths(default_cache_base, "mpv_thumbs_cache"),

    ------------------------
    -- Generation options --
    ------------------------

    -- Automatically generate the thumbnails on video load, without a keypress
    autogenerate = true,

    -- Only automatically thumbnail videos shorter than this (seconds)
    autogenerate_max_duration = 3600, -- 1 hour

    -- SHA1-sum filenames over this length
    -- It's nice to know what files the thumbnails are (hence directory names)
    -- but long URLs may approach filesystem limits.
    hash_filename_length = 128,

    -- Use mpv to generate thumbnail even if ffmpeg is found in PATH
    -- ffmpeg does not handle ordered chapters (MKVs which rely on other MKVs)!
    -- mpv is a bit slower, but has better support overall (eg. subtitles in the previews)
    prefer_mpv = true,

    -- Explicitly disable subtitles on the mpv sub-calls
    mpv_no_sub = false,
    -- Add a "--no-config" to the mpv sub-call arguments
    mpv_no_config = false,
    -- Add a "--profile=<mpv_profile>" to the mpv sub-call arguments
    -- Use "" to disable
    mpv_profile = "",
    -- Output debug logs to <thumbnail_path>.log, ala <cache_directory>/<video_filename>/000000.bgra.log
    -- The logs are removed after successful encodes, unless you set mpv_keep_logs below
    mpv_logs = true,
    -- Keep all mpv logs, even the succesfull ones
    mpv_keep_logs = false,

    -- Disable the built-in keybind ("T") to add your own
    disable_keybinds = false,

    ---------------------
    -- Display options --
    ---------------------

    -- Move the thumbnail up or down
    -- For example:
    --   topbar/bottombar: 24
    --   rest: 0
    vertical_offset = 24,

    -- Adjust background padding
    -- Examples:
    --   topbar:       0, 10, 10, 10
    --   bottombar:   10,  0, 10, 10
    --   slimbox/box: 10, 10, 10, 10
    pad_top   = 10,
    pad_bot   =  0,
    pad_left  = 10,
    pad_right = 10,

    -- If true, pad values are screen-pixels. If false, video-pixels.
    pad_in_screenspace = true,
    -- Calculate pad into the offset
    offset_by_pad = true,

    -- Background color in BBGGRR
    background_color = "000000",
    -- Alpha: 0 - fully opaque, 255 - transparent
    background_alpha = 80,

    -- Keep thumbnail on the screen near left or right side
    constrain_to_screen = true,

    -- Do not display the thumbnailing progress
    hide_progress = false,

    -----------------------
    -- Thumbnail options --
    -----------------------

    -- The maximum dimensions of the thumbnails (pixels)
    thumbnail_width = 200,
    thumbnail_height = 200,

    -- The thumbnail count target
    -- (This will result in a thumbnail every ~10 seconds for a 25 minute video)
    thumbnail_count = 150,

    -- The above target count will be adjusted by the minimum and
    -- maximum time difference between thumbnails.
    -- The thumbnail_count will be used to calculate a target separation,
    -- and min/max_delta will be used to constrict it.

    -- In other words, thumbnails will be:
    --   at least min_delta seconds apart (limiting the amount)
    --   at most max_delta seconds apart (raising the amount if needed)
    min_delta = 5,
    -- 120 seconds aka 2 minutes will add more thumbnails when the video is over 5 hours!
    max_delta = 90,


    -- Overrides for remote urls (you generally want less thumbnails!)
    -- Thumbnailing network paths will be done with mpv

    -- Allow thumbnailing network paths (naive check for "://")
    thumbnail_network = false,
    -- Override thumbnail count, min/max delta
    remote_thumbnail_count = 60,
    remote_min_delta = 15,
    remote_max_delta = 120,

    -- Try to grab the raw stream and disable ytdl for the mpv subcalls
    -- Much faster than passing the url to ytdl again, but may cause problems with some sites
    remote_direct_stream = true,
}

read_options(thumbnailer_options, SCRIPT_NAME)
local Thumbnailer = {
    cache_directory = thumbnailer_options.cache_directory,

    state = {
        ready = false,
        available = false,
        enabled = false,

        thumbnail_template = nil,

        thumbnail_delta = nil,
        thumbnail_count = 0,

        thumbnail_size = nil,

        finished_thumbnails = 0,

        -- List of thumbnail states (from 1 to thumbnail_count)
        -- ready: 1
        -- in progress: 0
        -- not ready: -1
        thumbnails = {},

        worker_input_path = nil,
        -- Extra options for the workers
        worker_extra = {},
    },
    -- Set in register_client
    worker_register_timeout = nil,
    -- A timer used to wait for more workers in case we have none
    worker_wait_timer = nil,
    workers = {}
}

function Thumbnailer:clear_state()
    clear_table(self.state)
    self.state.ready = false
    self.state.available = false
    self.state.finished_thumbnails = 0
    self.state.thumbnails = {}
    self.state.worker_extra = {}
end


function Thumbnailer:on_file_loaded()
    self:clear_state()
end

function Thumbnailer:on_thumb_ready(index)
    self.state.thumbnails[index] = 1

    -- Full recount instead of a naive increment (let's be safe!)
    self.state.finished_thumbnails = 0
    for i, v in pairs(self.state.thumbnails) do
        if v > 0 then
            self.state.finished_thumbnails = self.state.finished_thumbnails + 1
        end
    end
end

function Thumbnailer:on_thumb_progress(index)
    self.state.thumbnails[index] = math.max(self.state.thumbnails[index], 0)
end

function Thumbnailer:on_start_file()
    -- Clear state when a new file is being loaded
    self:clear_state()
end

function Thumbnailer:on_video_change(params)
    -- Gather a new state when we get proper video-dec-params and our state is empty
    if params ~= nil then
        if not self.state.ready then
            self:update_state()
        end
    end
end


function Thumbnailer:update_state()
    msg.debug("Gathering video/thumbnail state")

    self.state.thumbnail_delta = self:get_delta()
    self.state.thumbnail_count = self:get_thumbnail_count(self.state.thumbnail_delta)

    -- Prefill individual thumbnail states
    for i = 1, self.state.thumbnail_count do
        self.state.thumbnails[i] = -1
    end

    self.state.thumbnail_template, self.state.thumbnail_directory = self:get_thumbnail_template()
    self.state.thumbnail_size = self:get_thumbnail_size()

    self.state.ready = true

    local file_path = mp.get_property_native("path")
    self.state.is_remote = file_path:find("://") ~= nil

    self.state.available = false

    -- Make sure the file has video (and not just albumart)
    local track_list = mp.get_property_native("track-list")
    local has_video = false
    for i, track in pairs(track_list) do
        if track.type == "video" and not track.external and not track.albumart then
            has_video = true
            break
        end
    end

    if has_video and self.state.thumbnail_delta ~= nil and self.state.thumbnail_size ~= nil and self.state.thumbnail_count > 0 then
        self.state.available = true
    end

    msg.debug("Thumbnailer.state:", utils.to_string(self.state))

end


function Thumbnailer:get_thumbnail_template()
    local file_path = mp.get_property_native("path")
    local is_remote = file_path:find("://") ~= nil

    local filename = mp.get_property_native("filename/no-ext")
    local filesize = mp.get_property_native("file-size", 0)

    if is_remote then
        filesize = 0
    end

    filename = filename:gsub('[^a-zA-Z0-9_.%-\' ]', '')
    -- Hash overly long filenames (most likely URLs)
    if #filename > thumbnailer_options.hash_filename_length then
        filename = sha1.hex(filename)
    end

    local file_key = ("%s-%d"):format(filename, filesize)

    local thumbnail_directory = join_paths(self.cache_directory, file_key)
    local file_template = join_paths(thumbnail_directory, "%06d.bgra")
    return file_template, thumbnail_directory
end


function Thumbnailer:get_thumbnail_size()
    local video_dec_params = mp.get_property_native("video-dec-params")
    local video_width = video_dec_params.dw
    local video_height = video_dec_params.dh
    if not (video_width and video_height) then
        return nil
    end

    local w, h
    if video_width > video_height then
        w = thumbnailer_options.thumbnail_width
        h = math.floor(video_height * (w / video_width))
    else
        h = thumbnailer_options.thumbnail_height
        w = math.floor(video_width * (h / video_height))
    end
    return { w=w, h=h }
end


function Thumbnailer:get_delta()
    local file_path = mp.get_property_native("path")
    local file_duration = mp.get_property_native("duration")
    local is_seekable = mp.get_property_native("seekable")

    -- Naive url check
    local is_remote = file_path:find("://") ~= nil

    local remote_and_disallowed = is_remote
    if is_remote and thumbnailer_options.thumbnail_network then
        remote_and_disallowed = false
    end

    if remote_and_disallowed or not is_seekable or not file_duration then
        -- Not a local path (or remote thumbnails allowed), not seekable or lacks duration
        return nil
    end

    local thumbnail_count = thumbnailer_options.thumbnail_count
    local min_delta = thumbnailer_options.min_delta
    local max_delta = thumbnailer_options.max_delta

    if is_remote then
        thumbnail_count = thumbnailer_options.remote_thumbnail_count
        min_delta = thumbnailer_options.remote_min_delta
        max_delta = thumbnailer_options.remote_max_delta
    end

    local target_delta = (file_duration / thumbnail_count)
    local delta = math.max(min_delta, math.min(max_delta, target_delta))

    return delta
end


function Thumbnailer:get_thumbnail_count(delta)
    if delta == nil then
        return 0
    end
    local file_duration = mp.get_property_native("duration")

    return math.ceil(file_duration / delta)
end

function Thumbnailer:get_closest(thumbnail_index)
    -- Given a 1-based index, find the closest available thumbnail and return it's 1-based index

    -- Check the direct thumbnail index first
    if self.state.thumbnails[thumbnail_index] > 0 then
        return thumbnail_index
    end

    local min_distance = self.state.thumbnail_count + 1
    local closest = nil

    -- Naive, inefficient, lazy. But functional.
    for index, value in pairs(self.state.thumbnails) do
        local distance = math.abs(index - thumbnail_index)
        if distance < min_distance and value > 0 then
            min_distance = distance
            closest = index
        end
    end
    return closest
end

function Thumbnailer:get_thumbnail_index(time_position)
    -- Returns a 1-based thumbnail index for the given timestamp (between 1 and thumbnail_count, inclusive)
    if self.state.thumbnail_delta and (self.state.thumbnail_count and self.state.thumbnail_count > 0) then
        return math.min(math.floor(time_position / self.state.thumbnail_delta) + 1, self.state.thumbnail_count)
    else
        return nil
    end
end

function Thumbnailer:get_thumbnail_path(time_position)
    -- Given a timestamp, return:
    --   the closest available thumbnail path (if any)
    --   the 1-based thumbnail index calculated from the timestamp
    --   the 1-based thumbnail index of the closest available (and used) thumbnail
    -- OR nil if thumbnails are not available.

    local thumbnail_index = self:get_thumbnail_index(time_position)
    if not thumbnail_index then return nil end

    local closest = self:get_closest(thumbnail_index)

    if closest ~= nil then
        return self.state.thumbnail_template:format(closest-1), thumbnail_index, closest
    else
        return nil, thumbnail_index, nil
    end
end

function Thumbnailer:register_client()
    self.worker_register_timeout = mp.get_time() + 2

    mp.register_script_message("mpv_thumbnail_script-ready", function(index, path)
        self:on_thumb_ready(tonumber(index), path)
    end)
    mp.register_script_message("mpv_thumbnail_script-progress", function(index, path)
        self:on_thumb_progress(tonumber(index), path)
    end)

    mp.register_script_message("mpv_thumbnail_script-worker", function(worker_name)
        if not self.workers[worker_name] then
            msg.debug("Registered worker", worker_name)
            self.workers[worker_name] = true
            mp.commandv("script-message-to", worker_name, "mpv_thumbnail_script-slaved")
        end
    end)

    -- Notify workers to generate thumbnails when video loads/changes
    -- This will be executed after the on_video_change (because it's registered after it)
    mp.observe_property("video-dec-params", "native", function()
        local duration = mp.get_property_native("duration")
        local max_duration = thumbnailer_options.autogenerate_max_duration

        if duration ~= nil and self.state.available and thumbnailer_options.autogenerate then
            -- Notify if autogenerate is on and video is not too long
            if duration < max_duration or max_duration == 0 then
                self:start_worker_jobs()
            end
        end
    end)

    local thumb_script_key = not thumbnailer_options.disable_keybinds and "T" or nil
    mp.add_key_binding(thumb_script_key, "generate-thumbnails", function()
        if self.state.available then
            mp.osd_message("Started thumbnailer jobs")
            self:start_worker_jobs()
        else
            mp.osd_message("Thumbnailing unavailable")
        end
    end)
end

function Thumbnailer:_create_thumbnail_job_order()
    -- Returns a list of 1-based thumbnail indices in a job order
    local used_frames = {}
    local work_frames = {}

    -- Pick frames in increasing frequency.
    -- This way we can do a quick few passes over the video and then fill in the gaps.
    for x = 6, 0, -1 do
        local nth = (2^x)

        for thi = 1, self.state.thumbnail_count, nth do
            if not used_frames[thi] then
                table.insert(work_frames, thi)
                used_frames[thi] = true
            end
        end
    end
    return work_frames
end

function Thumbnailer:prepare_source_path()
    local file_path = mp.get_property_native("path")

    if self.state.is_remote and thumbnailer_options.remote_direct_stream then
        -- Use the direct stream (possibly) provided by ytdl
        -- This skips ytdl on the sub-calls, making the thumbnailing faster
        -- Works well on YouTube, rest not really tested
        file_path = mp.get_property_native("stream-path")

        -- edl:// urls can get LONG. In which case, save the path (URL)
        -- to a temporary file and use that instead.
        local playlist_filename = join_paths(self.state.thumbnail_directory, "playlist.txt")

        if #file_path > 8000 then
            -- Path is too long for a playlist - just pass the original URL to
            -- workers and allow ytdl
            self.state.worker_extra.enable_ytdl = true
            file_path = mp.get_property_native("path")
            msg.warn("Falling back to original URL and ytdl due to LONG source path. This will be slow.")

        elseif #file_path > 1024 then
            local playlist_file = io.open(playlist_filename, "wb")
            if not playlist_file then
                msg.error(("Tried to write a playlist to %s but couldn't!"):format(playlist_file))
                return false
            end

            playlist_file:write(file_path .. "\n")
            playlist_file:close()

            file_path = "--playlist=" .. playlist_filename
            msg.warn("Using playlist workaround due to long source path")
        end
    end

    self.state.worker_input_path = file_path
    return true
end

function Thumbnailer:start_worker_jobs()
    -- Create directory for the thumbnails, if needed
    local l, err = utils.readdir(self.state.thumbnail_directory)
    if err then
        msg.debug("Creating thumbnail directory", self.state.thumbnail_directory)
        create_directories(self.state.thumbnail_directory)
    end

    -- Try to prepare the source path for workers, and bail if unable to do so
    if not self:prepare_source_path() then
        return
    end

    local worker_list = {}
    for worker_name in pairs(self.workers) do table.insert(worker_list, worker_name) end

    local worker_count = #worker_list

    -- In case we have a worker timer created already, clear it
    -- (For example, if the video-dec-params change in quick succession or the user pressed T, etc)
    if self.worker_wait_timer then
        self.worker_wait_timer:stop()
    end

    if worker_count == 0 then
        local now = mp.get_time()
        if mp.get_time() > self.worker_register_timeout then
            -- Workers have had their time to register but we have none!
            local err = "No thumbnail workers found. Make sure you are not missing a script!"
            msg.error(err)
            mp.osd_message(err, 3)

        else
            -- We may be too early. Delay the work start a bit to try again.
            msg.warn("No workers found. Waiting a bit more for them.")
            -- Wait at least half a second
            local wait_time = math.max(self.worker_register_timeout - now, 0.5)
            self.worker_wait_timer = mp.add_timeout(wait_time, function() self:start_worker_jobs() end)
        end

    else
        -- We have at least one worker. This may not be all of them, but they have had
        -- their time to register; we've done our best waiting for them.
        self.state.enabled = true

        msg.debug( ("Splitting %d thumbnails amongst %d worker(s)"):format(self.state.thumbnail_count, worker_count) )

        local frame_job_order = self:_create_thumbnail_job_order()
        local worker_jobs = {}
        for i = 1, worker_count do worker_jobs[worker_list[i]] = {} end

        -- Split frames amongst the workers
        for i, thumbnail_index in ipairs(frame_job_order) do
            local worker_id = worker_list[ ((i-1) % worker_count) + 1 ]
            table.insert(worker_jobs[worker_id], thumbnail_index)
        end

        local state_json_string = utils.format_json(self.state)
        msg.debug("Giving workers state:", state_json_string)

        for worker_name, worker_frames in pairs(worker_jobs) do
            if #worker_frames > 0 then
                local frames_json_string = utils.format_json(worker_frames)
                msg.debug("Assigning job to", worker_name, frames_json_string)
                mp.commandv("script-message-to", worker_name, "mpv_thumbnail_script-job", state_json_string, frames_json_string)
            end
        end
    end
end

mp.register_event("start-file", function() Thumbnailer:on_start_file() end)
mp.observe_property("video-dec-params", "native", function(name, params) Thumbnailer:on_video_change(params) end)

--
-- Parameters
--
-- default user option values
-- do not touch, change them in osc.conf
local user_opts = {
    showwindowed = true,        -- show OSC when windowed?
    showfullscreen = true,      -- show OSC when fullscreen?
    scalewindowed = 1,          -- scaling of the controller when windowed
    scalefullscreen = 1,        -- scaling of the controller when fullscreen
    scaleforcedwindow = 2,      -- scaling when rendered on a forced window
    vidscale = true,            -- scale the controller with the video?
    barmargin = 0,              -- vertical margin of top/bottombar
    boxalpha = 80,              -- alpha of the background box,
                                -- 0 (opaque) to 255 (fully transparent)
    hidetimeout = 500,          -- duration in ms until the OSC hides if no
                                -- mouse movement. enforced non-negative for the
                                -- user, but internally negative is "always-on".
    fadeduration = 200,         -- duration of fade out in ms, 0 = no fade
    deadzonesize = 0.5,         -- size of deadzone
    minmousemove = 0,           -- minimum amount of pixels the mouse has to
                                -- move between ticks to make the OSC show up
    iamaprogrammer = false,     -- use native mpv values and disable OSC
                                -- internal track list management (and some
                                -- functions that depend on it)
    layout = "modernx",         -- set thumbnail layout
    seekbarhandlesize = 0.6,    -- size ratio of the diamond and knob handle
    seekrangealpha = 200,       -- transparency of seekranges
    seekbarkeyframes = true,    -- use keyframes when dragging the seekbar
    title = "${media-title}",   -- string compatible with property-expansion
                                -- to be shown as OSC title
    tooltipborder = 1,          -- border of tooltip in bottom/topbar
    timetotal = false,          -- display total time instead of remaining time?
    timems = false,             -- display timecodes with milliseconds?
    visibility = "auto",        -- only used at init to set visibility_mode(...)
    showtitle = true,           -- show title in OSC
    showonpause = true,         -- whether to disable the hide timeout on pause
    windowcontrols = "auto",    -- whether to show window controls
    windowcontrols_alignment = "right", -- which side to show window controls on
    greenandgrumpy = false,     -- disable santa hat
    livemarkers = true,         -- update seekbar chapter markers on duration change
    chapters_osd = true,        -- whether to show chapters OSD on next/prev
    playlist_osd = true,        -- whether to show playlist OSD on next/prev
    chapter_fmt = "Chapter: %s", -- chapter print format for seekbar-hover. "no" to disable

    titlefont = "",             -- font used for the title above OSC and
                                -- in window controls bar
    blur_intensity = 150,       -- adjust the strength of the blur
    osc_color = "000000",       -- accent of the OSC and the title bar
    seekbarfg_color = "E39C42", -- color of the seekbar progress and handle
    seekbarbg_color = "FFFFFF", -- color of the remaining seekbar
                                -- do note that ASS tag's color code is used,
                                -- which is BGR, instead of the standard RGB.
}

-- read options from config and command-line
opt.read_options(user_opts, "osc", function(list) update_options(list) end)

-- mpv_thumbnail_script.lua --

-- Patch in msg.trace
if not msg.trace then
    msg.trace = function(...) return mp.log("trace", ...) end
end

-- Patch in utils.format_bytes_humanized
if not utils.format_bytes_humanized then
    utils.format_bytes_humanized = function(b)
        local d = {"Bytes", "KiB", "MiB", "GiB", "TiB", "PiB"}
        local i = 1
        while b >= 1024 do
            b = b / 1024
            i = i + 1
        end
        return string.format("%0.2f %s", b, d[i] and d[i] or "*1024^" .. (i-1))
    end
end

Thumbnailer:register_client()

function get_thumbnail_y_offset(thumb_size, msy)
    local layout = user_opts.layout
    local offset = 0

    if layout == "bottombar" then
        offset = 15 --+ margin
    elseif layout == "topbar" then
        offset = -(thumb_size.h * msy + 15)
    elseif layout == "box" then
        offset = 15
    elseif layout == "slimbox" then
        offset = 12
    end

    return offset / msy
end


local osc_thumb_state = {
    visible = false,
    overlay_id = 1,

    last_path = nil,
    last_x = nil,
    last_y = nil,
}

function hide_thumbnail()
    osc_thumb_state.visible = false
    osc_thumb_state.last_path = nil
    mp.command_native({ "overlay-remove", osc_thumb_state.overlay_id })
end

function display_thumbnail(pos, value, ass)
    -- If thumbnails are not available, bail
    if not (Thumbnailer.state.enabled and Thumbnailer.state.available) then
        return
    end

    local duration = mp.get_property_number("duration", nil)
    if not ((duration == nil) or (value == nil)) then
        target_position = duration * (value / 100)

        local msx, msy = get_virt_scale_factor()
        local osd_w, osd_h = mp.get_osd_size()

        local thumb_size = Thumbnailer.state.thumbnail_size
        local thumb_path, thumb_index, closest_index = Thumbnailer:get_thumbnail_path(target_position)

        local thumbs_ready = Thumbnailer.state.finished_thumbnails
        local thumbs_total = Thumbnailer.state.thumbnail_count
        local perc = math.floor((thumbs_ready / thumbs_total) * 100)

        local display_progress = thumbs_ready ~= thumbs_total and not thumbnailer_options.hide_progress

        local vertical_offset = thumbnailer_options.vertical_offset
        local padding = thumbnailer_options.background_padding

        local pad = {
            l = thumbnailer_options.pad_left, r = thumbnailer_options.pad_right,
            t = thumbnailer_options.pad_top, b = thumbnailer_options.pad_bot
        }
        if thumbnailer_options.pad_in_screenspace then
            pad.l = pad.l * msx
            pad.r = pad.r * msx
            pad.t = pad.t * msy
            pad.b = pad.b * msy
        end

        if thumbnailer_options.offset_by_pad then
            vertical_offset = vertical_offset + (user_opts.layout == "topbar" and pad.t or pad.b)
        end

        local ass_w = thumb_size.w * msx
        local ass_h = thumb_size.h * msy
        local y_offset = get_thumbnail_y_offset(thumb_size, 1)

        -- Constrain thumbnail display to window
        -- (ie. don't let it go off-screen left/right)
        if thumbnailer_options.constrain_to_screen and osd_w > (ass_w + pad.l + pad.r)/msx then
            local padded_left = (pad.l + (ass_w / 2))
            local padded_right = (pad.r + (ass_w / 2))
            if pos.x - padded_left < 0 then
                pos.x = padded_left
            elseif pos.x + padded_right > osd_w*msx then
                pos.x = osd_w*msx - padded_right
            end
        end

        local text_h = 30 * msy
        local bg_h = ass_h + (display_progress and text_h or 0)
        local bg_left = pos.x - ass_w/2
        local framegraph_h = 10 * msy

        local bg_top = nil
        local text_top = nil
        local framegraph_top = nil

        if user_opts.layout == "topbar" then
            bg_top = pos.y - ( y_offset + thumb_size.h ) + vertical_offset
            text_top = bg_top + ass_h + framegraph_h
            framegraph_top = bg_top + ass_h
            vertical_offset = -vertical_offset
        else
            bg_top = pos.y - y_offset - bg_h - vertical_offset
            text_top = bg_top
            framegraph_top = bg_top + 20 * msy
        end

        if display_progress then
            if user_opts.layout == "topbar" then
                pad.b = math.max(0, pad.b - 30)
            else
                pad.t = math.max(0, pad.t - 30)
            end
        end



        -- Draw background
        ass:new_event()
        ass:pos(bg_left, bg_top)
        ass:append(("{\\bord0\\1c&H%s&\\1a&H%X&}"):format(thumbnailer_options.background_color, thumbnailer_options.background_alpha))
        ass:draw_start()
        ass:rect_cw(-pad.l, -pad.t, ass_w+pad.r, bg_h+pad.b)
        ass:draw_stop()

        if display_progress then

            ass:new_event()
            ass:pos(pos.x, text_top)
            ass:an(8)
            -- Scale text to correct size
            ass:append(("{\\fs20\\bord0\\fscx%f\\fscy%f}"):format(100*msx, 100*msy))
            ass:append(("%d%% - %d/%d"):format(perc, thumbs_ready, thumbs_total))

            -- Draw the generation progress
            local block_w = thumb_size.w * (Thumbnailer.state.thumbnail_delta / duration) * msy
            local block_max_x = thumb_size.w * msy

            -- Draw finished thumbnail blocks (white)
            ass:new_event()
            ass:pos(bg_left, framegraph_top)
            ass:append(("{\\bord0\\1c&HFFFFFF&\\1a&H%X&"):format(0))
            ass:draw_start(2)
            for i, v in pairs(Thumbnailer.state.thumbnails) do
                if i ~= closest_index and v > 0 then
                    ass:rect_cw((i-1)*block_w, 0, math.min(block_max_x, i*block_w), framegraph_h)
                end
            end
            ass:draw_stop()

            -- Draw in-progress thumbnail blocks (grayish green)
            ass:new_event()
            ass:pos(bg_left, framegraph_top)
            ass:append(("{\\bord0\\1c&H44AA44&\\1a&H%X&"):format(0))
            ass:draw_start(2)
            for i, v in pairs(Thumbnailer.state.thumbnails) do
                if i ~= closest_index and v == 0 then
                    ass:rect_cw((i-1)*block_w, 0, math.min(block_max_x, i*block_w), framegraph_h)
                end
            end
            ass:draw_stop()

            if closest_index ~= nil then
                ass:new_event()
                ass:pos(bg_left, framegraph_top)
                ass:append(("{\\bord0\\1c&H4444FF&\\1a&H%X&"):format(0))
                ass:draw_start(2)
                ass:rect_cw((closest_index-1)*block_w, 0, math.min(block_max_x, closest_index*block_w), framegraph_h)
                ass:draw_stop()
            end
        end

        if thumb_path then
            local overlay_y_offset = get_thumbnail_y_offset(thumb_size, msy)

            local thumb_x = math.floor(pos.x / msx - thumb_size.w/2)
            local thumb_y = math.floor(pos.y / msy - thumb_size.h - overlay_y_offset - vertical_offset/msy)

            osc_thumb_state.visible = true
            if not (osc_thumb_state.last_path == thumb_path and osc_thumb_state.last_x == thumb_x and osc_thumb_state.last_y == thumb_y) then
                local overlay_add_args = {
                    "overlay-add", osc_thumb_state.overlay_id,
                    thumb_x, thumb_y,
                    thumb_path,
                    0,
                    "bgra",
                    thumb_size.w, thumb_size.h,
                    4 * thumb_size.w
                }
                mp.command_native(overlay_add_args)

                osc_thumb_state.last_path = thumb_path
                osc_thumb_state.last_x = thumb_x
                osc_thumb_state.last_y = thumb_y
            end
        end
    end
end

-- // mpv_thumbnail_script.lua // --

-----------------
-- modernx.lua --
-----------------

local osc_param = { -- calculated by osc_init()
    playresy = 0,                           -- canvas size Y
    playresx = 0,                           -- canvas size X
    display_aspect = 1,
    unscaled_y = 0,
    areas = {},
}

local osc_styles = {
    transBg = "{\\blur100\\bord" .. user_opts.blur_intensity .. "\\1c&H000000&\\3c&H" .. user_opts.osc_color .. "&}",
    seekbarBg = "{\\blur0\\bord0\\1c&H" .. user_opts.seekbarbg_color .. "&}",
    seekbarFg = "{\\blur1\\bord1\\1c&H" .. user_opts.seekbarfg_color .. "&}",

    elementDown = "{\\1c&H999999&}",
    bigButtons = "{\\blur0\\bord0\\1c&HFFFFFF&\\3c&HFFFFFF&\\fs28\\fnmodernx-osc-icon}",
    mediumButtons = "{\\blur0\\bord0\\1c&HFFFFFF&\\3c&HFFFFFF&\\fs24\\fnmodernx-osc-icon}",
    smallButtons = "{\\blur0\\bord0\\1c&HFFFFFF&\\3c&HFFFFFF&\\fs24\\fnmodernx-osc-icon}",

    timecodes = "{\\blur0\\bord0\\1c&HFFFFFF&\\3c&H000000&\\fs22}",
    tooltip = "{\\blur1\\bord" .. user_opts.tooltipborder .. "\\1c&HFFFFFF&\\3c&H000000&\\fs20}",
    vidTitle = "{\\blur1\\bord0.5\\1c&HFFFFFF&\\3c&H0\\fs32\\q2\\fn" .. user_opts.titlefont .. "}",

    wcButtons = "{\\1c&HFFFFFF\\fs20\\fnmodernx-osc-icon}",
    wcTitle = "{\\1c&HFFFFFF\\fs24\\q2\\fn" .. user_opts.titlefont .. "}",
    wcBar = "{\\1c&H" .. user_opts.osc_color .. "}",
}

-- internal states, do not touch
local state = {
    showtime,                               -- time of last invocation (last mouse move)
    osc_visible = false,
    anistart,                               -- time when the animation started
    anitype,                                -- current type of animation
    animation,                              -- current animation alpha
    mouse_down_counter = 0,                 -- used for softrepeat
    active_element = nil,                   -- nil = none, 0 = background, 1+ = see elements[]
    active_event_source = nil,              -- the "button" that issued the current event
    rightTC_trem = not user_opts.timetotal, -- if the right timecode should display total or remaining time
    tc_ms = user_opts.timems,               -- Should the timecodes display their time with milliseconds
    mp_screen_sizeX, mp_screen_sizeY,       -- last screen-resolution, to detect resolution changes to issue reINITs
    initREQ = false,                        -- is a re-init request pending?
    last_mouseX, last_mouseY,               -- last mouse position, to detect significant mouse movement
    mouse_in_window = false,
    message_text,
    message_hide_timer,
    fullscreen = false,
    tick_timer = nil,
    tick_last_time = 0,                     -- when the last tick() was run
    hide_timer = nil,
    cache_state = nil,
    idle = false,
    enabled = true,
    input_enabled = true,
    showhide_enabled = false,
    dmx_cache = 0,
    border = true,
    maximized = false,
    osd = mp.create_osd_overlay("ass-events"),
    lastvisibility = user_opts.visibility,	-- save last visibility on pause if showonpause
}

local window_control_box_width = 80
local tick_delay = 0.03

local is_december = os.date("*t").month == 12

--- Automatically disable OSC
local builtin_osc_enabled = mp.get_property_native("osc")
if builtin_osc_enabled then
    mp.set_property_native("osc", false)
end

--
-- Helperfunctions
--

function kill_animation()
    state.anistart = nil
    state.animation = nil
    state.anitype =  nil
end

function set_osd(res_x, res_y, text)
    if state.osd.res_x == res_x and
       state.osd.res_y == res_y and
       state.osd.data == text then
        return
    end
    state.osd.res_x = res_x
    state.osd.res_y = res_y
    state.osd.data = text
    state.osd.z = 1000
    state.osd:update()
end

-- scale factor for translating between real and virtual ASS coordinates
function get_virt_scale_factor()
    local w, h = mp.get_osd_size()
    if w <= 0 or h <= 0 then
        return 0, 0
    end
    return osc_param.playresx / w, osc_param.playresy / h
end

-- return mouse position in virtual ASS coordinates (playresx/y)
function get_virt_mouse_pos()
    if state.mouse_in_window then
        local sx, sy = get_virt_scale_factor()
        local x, y = mp.get_mouse_pos()
        return x * sx, y * sy
    else
        return -1, -1
    end
end

function set_virt_mouse_area(x0, y0, x1, y1, name)
    local sx, sy = get_virt_scale_factor()
    mp.set_mouse_area(x0 / sx, y0 / sy, x1 / sx, y1 / sy, name)
end

function scale_value(x0, x1, y0, y1, val)
    local m = (y1 - y0) / (x1 - x0)
    local b = y0 - (m * x0)
    return (m * val) + b
end

-- returns hitbox spanning coordinates (top left, bottom right corner)
-- according to alignment
function get_hitbox_coords(x, y, an, w, h)

    local alignments = {
      [1] = function () return x, y-h, x+w, y end,
      [2] = function () return x-(w/2), y-h, x+(w/2), y end,
      [3] = function () return x-w, y-h, x, y end,

      [4] = function () return x, y-(h/2), x+w, y+(h/2) end,
      [5] = function () return x-(w/2), y-(h/2), x+(w/2), y+(h/2) end,
      [6] = function () return x-w, y-(h/2), x, y+(h/2) end,

      [7] = function () return x, y, x+w, y+h end,
      [8] = function () return x-(w/2), y, x+(w/2), y+h end,
      [9] = function () return x-w, y, x, y+h end,
    }

    return alignments[an]()
end

function get_hitbox_coords_geo(geometry)
    return get_hitbox_coords(geometry.x, geometry.y, geometry.an,
        geometry.w, geometry.h)
end

function get_element_hitbox(element)
    return element.hitbox.x1, element.hitbox.y1,
        element.hitbox.x2, element.hitbox.y2
end

function mouse_hit(element)
    return mouse_hit_coords(get_element_hitbox(element))
end

function mouse_hit_coords(bX1, bY1, bX2, bY2)
    local mX, mY = get_virt_mouse_pos()
    return (mX >= bX1 and mX <= bX2 and mY >= bY1 and mY <= bY2)
end

function limit_range(min, max, val)
    if val > max then
        val = max
    elseif val < min then
        val = min
    end
    return val
end

-- translate value into element coordinates
function get_slider_ele_pos_for(element, val)

    local ele_pos = scale_value(
        element.slider.min.value, element.slider.max.value,
        element.slider.min.ele_pos, element.slider.max.ele_pos,
        val)

    return limit_range(
        element.slider.min.ele_pos, element.slider.max.ele_pos,
        ele_pos)
end

-- translates global (mouse) coordinates to value
function get_slider_value_at(element, glob_pos)

    local val = scale_value(
        element.slider.min.glob_pos, element.slider.max.glob_pos,
        element.slider.min.value, element.slider.max.value,
        glob_pos)

    return limit_range(
        element.slider.min.value, element.slider.max.value,
        val)
end

-- get value at current mouse position
function get_slider_value(element)
    return get_slider_value_at(element, get_virt_mouse_pos())
end

function countone(val)
    if not (user_opts.iamaprogrammer) then
        val = val + 1
    end
    return val
end

-- align:  -1 .. +1
-- frame:  size of the containing area
-- obj:    size of the object that should be positioned inside the area
-- margin: min. distance from object to frame (as long as -1 <= align <= +1)
function get_align(align, frame, obj, margin)
    return (frame / 2) + (((frame / 2) - margin - (obj / 2)) * align)
end

-- multiplies two alpha values, formular can probably be improved
function mult_alpha(alphaA, alphaB)
    return 255 - (((1-(alphaA/255)) * (1-(alphaB/255))) * 255)
end

function add_area(name, x1, y1, x2, y2)
    -- create area if needed
    if (osc_param.areas[name] == nil) then
        osc_param.areas[name] = {}
    end
    table.insert(osc_param.areas[name], {x1=x1, y1=y1, x2=x2, y2=y2})
end

function ass_append_alpha(ass, alpha, modifier)
    local ar = {}

    for ai, av in pairs(alpha) do
        av = mult_alpha(av, modifier)
        if state.animation then
            av = mult_alpha(av, state.animation)
        end
        ar[ai] = av
    end

    ass:append(string.format("{\\1a&H%X&\\2a&H%X&\\3a&H%X&\\4a&H%X&}",
               ar[1], ar[2], ar[3], ar[4]))
end

function ass_draw_cir_cw(ass, x, y, r)
    ass:round_rect_cw(x-r, y-r, x+r, y+r, r)
end

function ass_draw_rr_h_cw(ass, x0, y0, x1, y1, r1, hexagon, r2)
    if hexagon then
        ass:hexagon_cw(x0, y0, x1, y1, r1, r2)
    else
        ass:round_rect_cw(x0, y0, x1, y1, r1, r2)
    end
end

function ass_draw_rr_h_ccw(ass, x0, y0, x1, y1, r1, hexagon, r2)
    if hexagon then
        ass:hexagon_ccw(x0, y0, x1, y1, r1, r2)
    else
        ass:round_rect_ccw(x0, y0, x1, y1, r1, r2)
    end
end


--
-- Tracklist Management
--

local nicetypes = {video = "Video", audio = "Audio", sub = "Subtitle"}

-- updates the OSC internal playlists, should be run each time the track-layout changes
function update_tracklist()
    local tracktable = mp.get_property_native("track-list", {})

    -- by osc_id
    tracks_osc = {}
    tracks_osc.video, tracks_osc.audio, tracks_osc.sub = {}, {}, {}
    -- by mpv_id
    tracks_mpv = {}
    tracks_mpv.video, tracks_mpv.audio, tracks_mpv.sub = {}, {}, {}
    for n = 1, #tracktable do
        if not (tracktable[n].type == "unknown") then
            local type = tracktable[n].type
            local mpv_id = tonumber(tracktable[n].id)

            -- by osc_id
            table.insert(tracks_osc[type], tracktable[n])

            -- by mpv_id
            tracks_mpv[type][mpv_id] = tracktable[n]
            tracks_mpv[type][mpv_id].osc_id = #tracks_osc[type]
        end
    end
end

-- return a nice list of tracks of the given type (video, audio, sub)
function get_tracklist(type)
    local msg = "Available " .. nicetypes[type] .. " Tracks: "
    if #tracks_osc[type] == 0 then
        msg = msg .. "none"
    else
        for n = 1, #tracks_osc[type] do
            local track = tracks_osc[type][n]
            local lang, title, selected = "unknown", "", "○"
            if not(track.lang == nil) then lang = track.lang end
            if not(track.title == nil) then title = track.title end
            if (track.id == tonumber(mp.get_property(type))) then
                selected = "●"
            end
            msg = msg.."\n"..selected.." "..n..": ["..lang.."] "..title
        end
    end
    return msg
end

-- relatively change the track of given <type> by <next> tracks
    --(+1 -> next, -1 -> previous)
function set_track(type, next)
    local current_track_mpv, current_track_osc
    if (mp.get_property(type) == "no") then
        current_track_osc = 0
    else
        current_track_mpv = tonumber(mp.get_property(type))
        current_track_osc = tracks_mpv[type][current_track_mpv].osc_id
    end
    local new_track_osc = (current_track_osc + next) % (#tracks_osc[type] + 1)
    local new_track_mpv
    if new_track_osc == 0 then
        new_track_mpv = "no"
    else
        new_track_mpv = tracks_osc[type][new_track_osc].id
    end

    mp.commandv("set", type, new_track_mpv)

    if (new_track_osc == 0) then
        show_message(nicetypes[type] .. " Track: none")
    else
        show_message(nicetypes[type]  .. " Track: "
            .. new_track_osc .. "/" .. #tracks_osc[type]
            .. " [".. (tracks_osc[type][new_track_osc].lang or "unknown") .."] "
            .. (tracks_osc[type][new_track_osc].title or ""))
    end
end

-- get the currently selected track of <type>, OSC-style counted
function get_track(type)
    local track = mp.get_property(type)
    if track ~= "no" and track ~= nil then
        local tr = tracks_mpv[type][tonumber(track)]
        if tr then
            return tr.osc_id
        end
    end
    return 0
end

-- WindowControl helpers
function window_controls_enabled()
    val = user_opts.windowcontrols
    if val == "auto" then
        return not state.border
    else
        return val ~= "no"
    end
end

function window_controls_alignment()
    return user_opts.windowcontrols_alignment
end

--
-- Element Management
--

local elements = {}

function prepare_elements()

    -- remove elements without layout or invisble
    local elements2 = {}
    for n, element in pairs(elements) do
        if not (element.layout == nil) and (element.visible) then
            table.insert(elements2, element)
        end
    end
    elements = elements2

    function elem_compare (a, b)
        return a.layout.layer < b.layout.layer
    end

    table.sort(elements, elem_compare)


    for _,element in pairs(elements) do

        local elem_geo = element.layout.geometry

        -- Calculate the hitbox
        local bX1, bY1, bX2, bY2 = get_hitbox_coords_geo(elem_geo)
        element.hitbox = {x1 = bX1, y1 = bY1, x2 = bX2, y2 = bY2}

        local style_ass = assdraw.ass_new()

        -- prepare static elements
        style_ass:append("{}") -- hack to troll new_event into inserting a \n
        style_ass:new_event()
        style_ass:pos(elem_geo.x, elem_geo.y)
        style_ass:an(elem_geo.an)
        style_ass:append(element.layout.style)

        element.style_ass = style_ass

        local static_ass = assdraw.ass_new()


        if (element.type == "box") then
            --draw box
            static_ass:draw_start()
            ass_draw_rr_h_cw(static_ass, 0, 0, elem_geo.w, elem_geo.h,
                             element.layout.box.radius, element.layout.box.hexagon)
            static_ass:draw_stop()

        elseif (element.type == "slider") then
            --draw static slider parts
            local slider_lo = element.layout.slider
            -- calculate positions of min and max points
            element.slider.min.ele_pos = user_opts.seekbarhandlesize * elem_geo.h / 2
            element.slider.max.ele_pos = elem_geo.w - element.slider.min.ele_pos
            element.slider.min.glob_pos = element.hitbox.x1 + element.slider.min.ele_pos
            element.slider.max.glob_pos = element.hitbox.x1 + element.slider.max.ele_pos

            static_ass:draw_start()
            -- a hack which prepares the whole slider area to allow center placements such like an=5
            static_ass:rect_cw(0, 0, elem_geo.w, elem_geo.h)
            static_ass:rect_ccw(0, 0, elem_geo.w, elem_geo.h)
            -- marker nibbles
            if not (element.slider.markerF == nil) and (slider_lo.gap > 0) then
                local markers = element.slider.markerF()
                for _,marker in pairs(markers) do
                    if (marker >= element.slider.min.value) and (marker <= element.slider.max.value) then
                        local s = get_slider_ele_pos_for(element, marker)
                        if (slider_lo.gap > 5) then -- draw triangles
                            --top
                            if (slider_lo.nibbles_top) then
                                static_ass:move_to(s - 3, slider_lo.gap - 5)
                                static_ass:line_to(s + 3, slider_lo.gap - 5)
                                static_ass:line_to(s, slider_lo.gap - 1)
                            end
                            --bottom
                            if (slider_lo.nibbles_bottom) then
                                static_ass:move_to(s - 3, elem_geo.h - slider_lo.gap + 5)
                                static_ass:line_to(s, elem_geo.h - slider_lo.gap + 1)
                                static_ass:line_to(s + 3, elem_geo.h - slider_lo.gap + 5)
                            end
                        else -- draw 2x1px nibbles
                            --top
                            if (slider_lo.nibbles_top) then
                                static_ass:rect_cw(s - 1, 0, s + 1, slider_lo.gap);
                            end
                            --bottom
                            if (slider_lo.nibbles_bottom) then
                                static_ass:rect_cw(s - 1, elem_geo.h-slider_lo.gap, s + 1, elem_geo.h);
                            end
                        end
                    end
                end
            end
        end

        element.static_ass = static_ass


        -- if the element is supposed to be disabled,
        -- style it accordingly and kill the eventresponders
        if not (element.enabled) then
            element.layout.alpha[1] = 136
            element.eventresponder = nil
        end
    end
end


--
-- Element Rendering
--

-- returns nil or a chapter element from the native property chapter-list
function get_chapter(possec)
    local cl = mp.get_property_native("chapter-list", {})
    local ch = nil

    -- chapters might not be sorted by time. find nearest-before/at possec
    for n=1, #cl do
        if possec >= cl[n].time and (not ch or cl[n].time > ch.time) then
            ch = cl[n]
        end
    end
    return ch
end

function render_elements(master_ass)

    -- when the slider is dragged or hovered and we have a target chapter name
    -- then we use it instead of the normal title. we calculate it before the
    -- render iterations because the title may be rendered before the slider.
    state.forced_title = nil
    local se, ae = state.slider_element, elements[state.active_element]
    if user_opts.chapter_fmt ~= "no" and se and (ae == se or (not ae and mouse_hit(se))) then
        local dur = mp.get_property_number("duration", 0)
        if dur > 0 then
            local possec = get_slider_value(se) * dur / 100 -- of mouse pos
            local ch = get_chapter(possec)
            if ch and ch.title and ch.title ~= "" then
                state.forced_title = string.format(user_opts.chapter_fmt, ch.title)
            end
        end
    end

    for n=1, #elements do
        local element = elements[n]

        local style_ass = assdraw.ass_new()
        style_ass:merge(element.style_ass)
        ass_append_alpha(style_ass, element.layout.alpha, 0)

        if element.eventresponder and (state.active_element == n) then

            -- run render event functions
            if not (element.eventresponder.render == nil) then
                element.eventresponder.render(element)
            end

            if mouse_hit(element) then
                -- mouse down styling
                if (element.styledown) then
                    style_ass:append(osc_styles.elementDown)
                end

                if (element.softrepeat) and (state.mouse_down_counter >= 15
                    and state.mouse_down_counter % 5 == 0) then

                    element.eventresponder[state.active_event_source.."_down"](element)
                end
                state.mouse_down_counter = state.mouse_down_counter + 1
            end

        end

        local elem_ass = assdraw.ass_new()

        elem_ass:merge(style_ass)

        if not (element.type == "button") then
            elem_ass:merge(element.static_ass)
        end

        if (element.type == "slider") then

            local slider_lo = element.layout.slider
            local elem_geo = element.layout.geometry
            local s_min = element.slider.min.value
            local s_max = element.slider.max.value

            -- draw pos marker
            local pos = element.slider.posF()
            local seekRanges = element.slider.seekRangesF()
            local rh = user_opts.seekbarhandlesize * elem_geo.h / 2 -- Handle radius
            local xp

            if pos then
                xp = get_slider_ele_pos_for(element, pos)
                ass_draw_cir_cw(elem_ass, xp, elem_geo.h/2, rh)
                elem_ass:rect_cw(0, slider_lo.gap, xp, elem_geo.h - slider_lo.gap)
            end

            if seekRanges then
                elem_ass:draw_stop()
                elem_ass:merge(element.style_ass)
                ass_append_alpha(elem_ass, element.layout.alpha, user_opts.seekrangealpha)
                elem_ass:merge(element.static_ass)

                for _,range in pairs(seekRanges) do
                    local pstart = get_slider_ele_pos_for(element, range["start"])
                    local pend = get_slider_ele_pos_for(element, range["end"])
                    elem_ass:rect_cw(pstart - rh, slider_lo.gap, pend + rh, elem_geo.h - slider_lo.gap)
                end
            end

            elem_ass:draw_stop()

            -- add tooltip
            if not (element.slider.tooltipF == nil) then

                if mouse_hit(element) then
                    local sliderpos = get_slider_value(element)
                    local tooltiplabel = element.slider.tooltipF(sliderpos)

                    local an = slider_lo.tooltip_an

                    local ty

                    if (an == 2) then
                        ty = element.hitbox.y1
                    else
                        ty = element.hitbox.y1 + elem_geo.h/2
                    end

                    local tx = get_virt_mouse_pos()
                    if (slider_lo.adjust_tooltip) then
                        if (an == 2) then
                            if (sliderpos < (s_min + 3)) then
                                an = an - 1
                            elseif (sliderpos > (s_max - 3)) then
                                an = an + 1
                            end
                        elseif (sliderpos > (s_max-s_min)/2) then
                            an = an + 1
                            tx = tx - 5
                        else
                            an = an - 1
                            tx = tx + 10
                        end
                    end

                    -- tooltip label
                    elem_ass:new_event()
                    elem_ass:pos(tx, ty)
                    elem_ass:an(an)
                    elem_ass:append(slider_lo.tooltip_style)
                    ass_append_alpha(elem_ass, slider_lo.alpha, 0)
                    elem_ass:append(tooltiplabel)

                     -- mpv_thumbnail_script.lua --
                    display_thumbnail({x=get_virt_mouse_pos(), y=ty, a=an}, sliderpos, elem_ass)
                    -- // mpv_thumbnail_script.lua // --
                end
            end

        elseif (element.type == "button") then

            local buttontext
            if type(element.content) == "function" then
                buttontext = element.content() -- function objects
            elseif not (element.content == nil) then
                buttontext = element.content -- text objects
            end

            local maxchars = element.layout.button.maxchars
            if not (maxchars == nil) and (#buttontext > maxchars) then
                local max_ratio = 1.25  -- up to 25% more chars while shrinking
                local limit = math.max(0, math.floor(maxchars * max_ratio) - 3)
                if (#buttontext > limit) then
                    while (#buttontext > limit) do
                        buttontext = buttontext:gsub(".[\128-\191]*$", "")
                    end
                    buttontext = buttontext .. "..."
                end
                local _, nchars2 = buttontext:gsub(".[\128-\191]*", "")
                local stretch = (maxchars/#buttontext)*100
                buttontext = string.format("{\\fscx%f}",
                    (maxchars/#buttontext)*100) .. buttontext
            end

            elem_ass:append(buttontext)

            -- add tooltip for audio and subtitle tracks
            if not (element.tooltipF == nil) and element.enabled then
                if mouse_hit(element) then
                    local tooltiplabel = element.tooltipF
                    local an = 1
                    local ty = element.hitbox.y1
                    local tx = get_virt_mouse_pos()

                    if ty < osc_param.playresy / 2 then
                        ty = element.hitbox.y2
                        an = 7
                    end

                    -- tooltip label
                    if type(element.tooltipF) == "function" then
                        tooltiplabel = element.tooltipF()
                    else
                        tooltiplabel = element.tooltipF
                    end
                    elem_ass:new_event()
                    elem_ass:pos(tx, ty)
                    elem_ass:an(an)
                    elem_ass:append(element.tooltip_style)
                    elem_ass:append(tooltiplabel)
                end
            end
        end

        master_ass:merge(elem_ass)
    end
end

--
-- Message display
--

-- pos is 1 based
function limited_list(prop, pos)
    local proplist = mp.get_property_native(prop, {})
    local count = #proplist
    if count == 0 then
        return count, proplist
    end

    local fs = tonumber(mp.get_property('options/osd-font-size'))
    local max = math.ceil(osc_param.unscaled_y*0.75 / fs)
    if max % 2 == 0 then
        max = max - 1
    end
    local delta = math.ceil(max / 2) - 1
    local begi = math.max(math.min(pos - delta, count - max + 1), 1)
    local endi = math.min(begi + max - 1, count)

    local reslist = {}
    for i=begi, endi do
        local item = proplist[i]
        item.current = (i == pos) and true or nil
        table.insert(reslist, item)
    end
    return count, reslist
end

function get_playlist()
    local pos = mp.get_property_number('playlist-pos', 0) + 1
    local count, limlist = limited_list('playlist', pos)
    if count == 0 then
        return 'Empty playlist.'
    end

    local message = string.format('Playlist [%d/%d]:\n', pos, count)
    for i, v in ipairs(limlist) do
        local title = v.title
        local _, filename = utils.split_path(v.filename)
        if title == nil then
            title = filename
        end
        message = string.format('%s %s %s\n', message,
            (v.current and '●' or '○'), title)
    end
    return message
end

function get_chapterlist()
    local pos = mp.get_property_number('chapter', 0) + 1
    local count, limlist = limited_list('chapter-list', pos)
    if count == 0 then
        return 'No chapters.'
    end

    local message = string.format('Chapters [%d/%d]:\n', pos, count)
    for i, v in ipairs(limlist) do
        local time = mp.format_time(v.time)
        local title = v.title
        if title == nil then
            title = string.format('Chapter %02d', i)
        end
        message = string.format('%s[%s] %s %s\n', message, time,
            (v.current and '●' or '○'), title)
    end
    return message
end

function show_message(text, duration)

    --print("text: "..text.."   duration: " .. duration)
    if duration == nil then
        duration = tonumber(mp.get_property("options/osd-duration")) / 1000
    elseif not type(duration) == "number" then
        print("duration: " .. duration)
    end

    -- cut the text short, otherwise the following functions
    -- may slow down massively on huge input
    text = string.sub(text, 0, 4000)

    -- replace actual linebreaks with ASS linebreaks
    text = string.gsub(text, "\n", "\\N")

    state.message_text = text

    if not state.message_hide_timer then
        state.message_hide_timer = mp.add_timeout(0, request_tick)
    end
    state.message_hide_timer:kill()
    state.message_hide_timer.timeout = duration
    state.message_hide_timer:resume()
    request_tick()
end

function render_message(ass)
    if state.message_hide_timer and state.message_hide_timer:is_enabled() and
       state.message_text
    then
        local _, lines = string.gsub(state.message_text, "\\N", "")

        local fontsize = tonumber(mp.get_property("options/osd-font-size"))
        local outline = tonumber(mp.get_property("options/osd-border-size"))
        local maxlines = math.ceil(osc_param.unscaled_y*0.75 / fontsize)
        local counterscale = osc_param.playresy / osc_param.unscaled_y

        fontsize = fontsize * counterscale / math.max(0.65 + math.min(lines/maxlines, 1), 1)
        outline = outline * counterscale / math.max(0.75 + math.min(lines/maxlines, 1)/2, 1)

        local style = "{\\bord" .. outline .. "\\fs" .. fontsize .. "}"


        ass:new_event()
        ass:append(style .. state.message_text)
    else
        state.message_text = nil
    end
end

--
-- Initialisation and Layout
--

function new_element(name, type)
    elements[name] = {}
    elements[name].type = type

    -- add default stuff
    elements[name].eventresponder = {}
    elements[name].visible = true
    elements[name].enabled = true
    elements[name].softrepeat = false
    elements[name].styledown = (type == "button")
    elements[name].state = {}

    if (type == "slider") then
        elements[name].slider = {min = {value = 0}, max = {value = 100}}
    end


    return elements[name]
end

function add_layout(name)
    if not (elements[name] == nil) then
        -- new layout
        elements[name].layout = {}

        -- set layout defaults
        elements[name].layout.layer = 50
        elements[name].layout.alpha = {[1] = 0, [2] = 255, [3] = 255, [4] = 255}

        if (elements[name].type == "button") then
            elements[name].layout.button = {
                maxchars = nil,
            }
        elseif (elements[name].type == "slider") then
            -- slider defaults
            elements[name].layout.slider = {
                border = 1,
                gap = 1,
                nibbles_top = true,
                nibbles_bottom = true,
                adjust_tooltip = true,
                tooltip_style = "",
                tooltip_an = 2,
                alpha = {[1] = 0, [2] = 255, [3] = 88, [4] = 255},
            }
        elseif (elements[name].type == "box") then
            elements[name].layout.box = {radius = 0, hexagon = false}
        end

        return elements[name].layout
    else
        msg.error("Can't add_layout to element \""..name.."\", doesn't exist.")
    end
end

-- Window Controls
function window_controls()
    local wc_geo = {
        x = 0,
        y = 30 + user_opts.barmargin,
        an = 1,
        w = osc_param.playresx,
        h = 30,
    }

    local alignment = window_controls_alignment()
    local controlbox_w = window_control_box_width
    local titlebox_w = wc_geo.w - controlbox_w

    -- Default alignment is "right"
    local controlbox_left = wc_geo.w - controlbox_w
    local titlebox_left = wc_geo.x
    local titlebox_right = wc_geo.w - controlbox_w

    if alignment == "left" then
        controlbox_left = wc_geo.x + 10
        titlebox_left = wc_geo.x + controlbox_w + 10
        titlebox_right = wc_geo.w
    end

    add_area("window-controls",
             get_hitbox_coords(controlbox_left, wc_geo.y, wc_geo.an,
                               controlbox_w, wc_geo.h))

    local lo

    -- Background Bar
    new_element("wcbar", "box")
    lo = add_layout("wcbar")
    lo.geometry = wc_geo
    lo.layer = 10
    lo.style = osc_styles.wcBar
    lo.alpha[1] = user_opts.boxalpha

    local button_y = wc_geo.y - (wc_geo.h / 2)
    local first_geo =
        {x = controlbox_left - 5, y = button_y, an = 4, w = 25, h = 25}
    local second_geo =
        {x = controlbox_left + 25, y = button_y, an = 4, w = 25, h = 25}
    local third_geo =
        {x = controlbox_left + 55, y = button_y, an = 4, w = 25, h = 25}

    -- Window control buttons use symbols in the custom mpv osd font
    -- because the official unicode codepoints are sufficiently
    -- exotic that a system might lack an installed font with them,
    -- and libass will complain that they are not present in the
    -- default font, even if another font with them is available.

    -- Close: 🗙
    ne = new_element("close", "button")
    ne.content = "\xEE\xA4\x81"
    ne.eventresponder["mbtn_left_up"] =
        function () mp.commandv("quit") end
    lo = add_layout("close")
    lo.geometry = alignment == "left" and first_geo or third_geo
    lo.style = osc_styles.wcButtons

    -- Minimize: 🗕
    ne = new_element("minimize", "button")
    ne.content = "\xEE\xA4\x84"
    ne.eventresponder["mbtn_left_up"] =
        function () mp.commandv("cycle", "window-minimized") end
    lo = add_layout("minimize")
    lo.geometry = alignment == "left" and second_geo or first_geo
    lo.style = osc_styles.wcButtons

    -- Maximize: 🗖 /🗗
    ne = new_element("maximize", "button")
    if state.maximized or state.fullscreen then
        ne.content = "\xEE\xA4\x83"
    else
        ne.content = "\xEE\xA4\x82"
    end
    ne.eventresponder["mbtn_left_up"] =
        function ()
            if state.fullscreen then
                mp.commandv("cycle", "fullscreen")
            else
                mp.commandv("cycle", "window-maximized")
            end
        end
    lo = add_layout("maximize")
    lo.geometry = alignment == "left" and third_geo or second_geo
    lo.style = osc_styles.wcButtons

    -- deadzone below window controls
    local sh_area_y0, sh_area_y1
    sh_area_y0 = user_opts.barmargin
    sh_area_y1 = (wc_geo.y + (wc_geo.h / 2)) +
                 get_align(1 - (2 * user_opts.deadzonesize),
                 osc_param.playresy - (wc_geo.y + (wc_geo.h / 2)), 0, 0)
    add_area("showhide_wc", wc_geo.x, sh_area_y0, wc_geo.w, sh_area_y1)

    -- Window Title
    ne = new_element("wctitle", "button")
    ne.content = function ()
        local title = mp.command_native({"expand-text", user_opts.title})
        -- escape ASS, and strip newlines and trailing slashes
        title = title:gsub("\\n", " "):gsub("\\$", ""):gsub("{","\\{")
        return not (title == "") and title or "mpv"
    end
    local left_pad = 5
    local right_pad = 10
    lo = add_layout("wctitle")
    lo.geometry =
        { x = titlebox_left + left_pad, y = wc_geo.y - 3, an = 1,
          w = titlebox_w, h = wc_geo.h }
    lo.style = string.format("%s{\\clip(%f,%f,%f,%f)}",
        osc_styles.wcTitle,
        titlebox_left + left_pad, wc_geo.y - wc_geo.h,
        titlebox_right - right_pad , wc_geo.y + wc_geo.h)

    add_area("window-controls-title",
             titlebox_left, 0, titlebox_right, wc_geo.h)
end

--
-- Layouts
--

local layouts = {}

-- Default layout
layouts = function ()

    local osc_geo = {w, h}

    osc_geo.w = osc_param.playresx
    osc_geo.h = 180

    -- origin of the controllers, left/bottom corner
    local posX = 0
    local posY = osc_param.playresy

    osc_param.areas = {} -- delete areas

    -- area for active mouse input
    add_area("input", get_hitbox_coords(posX, posY, 1, osc_geo.w, osc_geo.h))

    -- deadzone above OSC
    local sh_area_y0, sh_area_y1
    sh_area_y0 = get_align(-1 + (2*user_opts.deadzonesize),
                           posY - (osc_geo.h / 2), 0, 0)
    sh_area_y1 = osc_param.playresy - user_opts.barmargin

    -- area for show/hide
    add_area("showhide", 0, sh_area_y0, osc_param.playresx, sh_area_y1)

    -- fetch values
    local osc_w, osc_h=
        osc_geo.w, osc_geo.h

    --
    -- Controller Background
    --
    local lo

    new_element("transBg", "box")
    lo = add_layout("transBg")
    lo.geometry = {x = posX, y = posY, an = 7, w = osc_w, h = 1}
    lo.style = osc_styles.transBg
    lo.layer = 10
    lo.alpha[3] = 0

    --
    -- Alignment
    --
    local refX = osc_w / 2
    local refY = posY
    local geo

    --
    -- Seekbar
    --
    new_element("bgbar1", "box")
    lo = add_layout("bgbar1")
    lo.geometry = {x = refX , y = refY - 100 , an = 5, w = osc_geo.w - 50, h = 2}
    lo.layer = 13
    lo.style = osc_styles.seekbarBg
    lo.alpha[1] = 128
    lo.alpha[3] = 128

    lo = add_layout("seekbar")
    lo.geometry = {x = refX, y = refY - 100 , an = 5, w = osc_geo.w - 50, h = 16}
    lo.style = osc_styles.seekbarFg
    lo.slider.gap = 7
    lo.slider.tooltip_style = osc_styles.tooltip
    lo.slider.tooltip_an = 2

    -- Title
    geo = {x = 25, y = refY - 132, an = 1, w = osc_geo.w - 50, h = 48}
    lo = add_layout("title")
    lo.geometry = {x = 25, y = refY - 132, an = 1, w = osc_geo.w - 50, h = 48}
    lo.style = string.format("%s{\\clip(%f,%f,%f,%f)}", osc_styles.vidTitle,
                                geo.x, geo.y - geo.h, geo.x + geo.w , geo.y)
    lo.alpha[3] = 0

    -- Buttons
    lo = add_layout("pl_prev")
    lo.geometry = {x = refX - 120, y = refY - 40 , an = 5, w = 30, h = 24}
    lo.style = osc_styles.mediumButtons

    lo = add_layout("skipback")
    lo.geometry = {x = refX - 60, y = refY - 40 , an = 5, w = 30, h = 24}
    lo.style = osc_styles.mediumButtons

    lo = add_layout("playpause")
    lo.geometry = {x = refX, y = refY - 40 , an = 5, w = 45, h = 45}
    lo.style = osc_styles.bigButtons

    lo = add_layout("skipfrwd")
    lo.geometry = {x = refX + 60, y = refY - 40 , an = 5, w = 30, h = 24}
    lo.style = osc_styles.mediumButtons

    lo = add_layout("pl_next")
    lo.geometry = {x = refX + 120, y = refY - 40 , an = 5, w = 30, h = 24}
    lo.style = osc_styles.mediumButtons

    -- Time
    lo = add_layout("tc_left")
    lo.geometry = {x = 25, y = refY - 90, an = 7, w = 120, h = 20}
    lo.style = osc_styles.timecodes

    lo = add_layout("tc_right")
    lo.geometry = {x = osc_geo.w - 25 , y = refY - 90, an = 9, w = 120, h = 20}
    lo.style = osc_styles.timecodes

    -- Cache
    lo = add_layout("cache")
    lo.geometry = {x = osc_geo.w - 117, y = refY - 50, an = 9, w = 64, h = 20}
    lo.style = osc_styles.timecodes

    -- Volume
    lo = add_layout("volume")
    lo.geometry = {x = 37, y = refY - 40, an = 5, w = 24, h = 24}
    lo.style = osc_styles.smallButtons

    -- Audio tracks
    lo = add_layout("cy_audio")
    lo.geometry = {x = 87, y = refY - 40, an = 5, w = 24, h = 24}
    lo.style = osc_styles.smallButtons

    -- Subtitle tracks
    lo = add_layout("cy_sub")
    lo.geometry = {x = 137, y = refY - 40, an = 5, w = 24, h = 24}
    lo.style = osc_styles.smallButtons

    -- Toggle fullscreen
    lo = add_layout("tog_fs")
    lo.geometry = {x = osc_geo.w - 37, y = refY - 40, an = 5, w = 24, h = 24}
    lo.style = osc_styles.smallButtons

    -- Toggle info
    lo = add_layout("tog_info")
    lo.geometry = {x = osc_geo.w - 87, y = refY - 40, an = 5, w = 24, h = 24}
    lo.style = osc_styles.smallButtons
end

-- Validate string type user options
function validate_user_opts()
    if user_opts.windowcontrols ~= "auto" and
       user_opts.windowcontrols ~= "yes" and
       user_opts.windowcontrols ~= "no" then
        msg.warn("windowcontrols cannot be \"" ..
                user_opts.windowcontrols .. "\". Ignoring.")
        user_opts.windowcontrols = "auto"
    end
    if user_opts.windowcontrols_alignment ~= "right" and
       user_opts.windowcontrols_alignment ~= "left" then
        msg.warn("windowcontrols_alignment cannot be \"" ..
                user_opts.windowcontrols_alignment .. "\". Ignoring.")
        user_opts.windowcontrols_alignment = "right"
    end
end

function update_options(list)
    validate_user_opts()
    request_tick()
    visibility_mode(user_opts.visibility, true)
    update_duration_watch()
    request_init()
end

-- OSC INIT
function osc_init()
    msg.debug("osc_init")

    -- set canvas resolution according to display aspect and scaling setting
    local baseResY = 720
    local display_w, display_h, display_aspect = mp.get_osd_size()
    local scale = 1

    if (mp.get_property("video") == "no") then -- dummy/forced window
        scale = user_opts.scaleforcedwindow
    elseif state.fullscreen then
        scale = user_opts.scalefullscreen
    else
        scale = user_opts.scalewindowed
    end

    if user_opts.vidscale then
        osc_param.unscaled_y = baseResY
    else
        osc_param.unscaled_y = display_h
    end
    osc_param.playresy = osc_param.unscaled_y / scale
    if (display_aspect > 0) then
        osc_param.display_aspect = display_aspect
    end
    osc_param.playresx = osc_param.playresy * osc_param.display_aspect

    -- stop seeking with the slider to prevent skipping files
    state.active_element = nil

    elements = {}

    -- some often needed stuff
    local pl_count = mp.get_property_number("playlist-count", 0)
    local have_pl = (pl_count > 1)
    local pl_pos = mp.get_property_number("playlist-pos", 0) + 1
    local have_ch = (mp.get_property_number("chapters", 0) > 0)
    local loop = mp.get_property("loop-playlist", "no")

    local ne

    -- title
    ne = new_element("title", "button")

    ne.content = function ()
        local title = state.forced_title or
                      mp.command_native({"expand-text", user_opts.title})
        -- escape ASS, and strip newlines and trailing slashes
        title = title:gsub("\\n", " "):gsub("\\$", ""):gsub("{","\\{")
        return not (title == "") and title or "mpv"
    end

    ne.eventresponder["mbtn_left_up"] = function ()
        local title = mp.get_property_osd("media-title")
        if (have_pl) then
            title = string.format("[%d/%d] %s", countone(pl_pos - 1),
                                  pl_count, title)
        end
        show_message(title)
    end

    ne.eventresponder["mbtn_right_up"] =
        function () show_message(mp.get_property_osd("filename")) end

    -- playlist buttons

    -- prev
    ne = new_element("pl_prev", "button")

    ne.content = "\xEE\xA4\x94"
    ne.enabled = (pl_pos > 1) or (loop ~= "no")
    ne.eventresponder["mbtn_left_up"] =
        function ()
            mp.commandv("playlist-prev", "weak")
            if user_opts.playlist_osd then
                show_message(get_playlist(), 3)
            end
        end
    ne.eventresponder["shift+mbtn_left_up"] =
        function () show_message(get_playlist(), 3) end
    ne.eventresponder["mbtn_right_up"] =
        function () show_message(get_playlist(), 3) end

    --next
    ne = new_element("pl_next", "button")

    ne.content = "\xEE\xA4\x99"
    ne.enabled = (have_pl and (pl_pos < pl_count)) or (loop ~= "no")
    ne.eventresponder["mbtn_left_up"] =
        function ()
            mp.commandv("playlist-next", "weak")
            if user_opts.playlist_osd then
                show_message(get_playlist(), 3)
                end
            end
    ne.eventresponder["shift+mbtn_left_up"] =
        function () show_message(get_playlist(), 3) end
    ne.eventresponder["mbtn_right_up"] =
        function () show_message(get_playlist(), 3) end


    -- big buttons

    --play control buttons
    ne = new_element("playpause", "button")

    ne.content = function ()
        if mp.get_property("pause") == "yes" then
            return ("\xEE\xA4\x96")
        else
            return ("\xEE\xA4\x97")
        end
    end
    ne.eventresponder["mbtn_left_up"] =
        function () mp.commandv("cycle", "pause") end

    --skipback
    ne = new_element("skipback", "button")

    ne.softrepeat = true
    ne.content = "\xEE\xA4\x95"
    ne.eventresponder["mbtn_left_down"] =
        function () mp.commandv("seek", -5, "relative", "keyframes") end
    ne.eventresponder["shift+mbtn_left_down"] =
        function () mp.commandv("frame-back-step") end
    ne.eventresponder["mbtn_right_down"] =
        function () mp.commandv("seek", -30, "relative", "keyframes") end

    --skipfrwd
    ne = new_element("skipfrwd", "button")

    ne.softrepeat = true
    ne.content = "\xEE\xA4\x98"
    ne.eventresponder["mbtn_left_down"] =
        function () mp.commandv("seek", 10, "relative", "keyframes") end
    ne.eventresponder["shift+mbtn_left_down"] =
        function () mp.commandv("frame-step") end
    ne.eventresponder["mbtn_right_down"] =
        function () mp.commandv("seek", 60, "relative", "keyframes") end

    --ch_prev
    ne = new_element("ch_prev", "button")

    ne.enabled = have_ch
    ne.content = "\238\132\132"
    ne.eventresponder["mbtn_left_up"] =
        function ()
            mp.commandv("add", "chapter", -1)
            if user_opts.chapters_osd then
                show_message(get_chapterlist(), 3)
            end
        end
    ne.eventresponder["shift+mbtn_left_up"] =
        function () show_message(get_chapterlist(), 3) end
    ne.eventresponder["mbtn_right_up"] =
        function () show_message(get_chapterlist(), 3) end

    --ch_next
    ne = new_element("ch_next", "button")

    ne.enabled = have_ch
    ne.content = "\238\132\133"
    ne.eventresponder["mbtn_left_up"] =
        function ()
            mp.commandv("add", "chapter", 1)
            if user_opts.chapters_osd then
                show_message(get_chapterlist(), 3)
            end
        end
    ne.eventresponder["shift+mbtn_left_up"] =
        function () show_message(get_chapterlist(), 3) end
    ne.eventresponder["mbtn_right_up"] =
        function () show_message(get_chapterlist(), 3) end

    --
    update_tracklist()

    --cy_audio
    ne = new_element("cy_audio", "button")

    ne.enabled = (#tracks_osc.audio > 0)
    ne.content = "\xEE\xA4\x89"
    ne.tooltip_style = osc_styles.tooltip
    ne.tooltipF = function ()
        local msg = "OFF"
        if not (get_track("audio") == 0) then
            msg = ("Audio" .. " [" .. get_track("audio") .. "∕" .. #tracks_osc.audio .. "] ")

            local prop = mp.get_property("current-tracks/audio/lang")
            if not prop then
                prop = "N/A"
            end
            msg = msg .. "(" .. prop .. ")"

            prop = mp.get_property("current-tracks/audio/title")
            if prop then
                msg = msg .. " " .. prop
            end
            return msg
        end
        return msg
    end
    ne.eventresponder["mbtn_left_up"] =
        function () set_track("audio", 1) end
    ne.eventresponder["mbtn_right_up"] =
        function () set_track("audio", -1) end
    ne.eventresponder["shift+mbtn_left_down"] =
        function () show_message(get_tracklist("audio"), 2) end

    --cy_sub
    ne = new_element("cy_sub", "button")

    ne.enabled = (#tracks_osc.sub > 0)
    ne.content = "\xEE\xA4\x90"
    ne.tooltip_style = osc_styles.tooltip
    ne.tooltipF = function ()
        local msg = "OFF"
        if not (get_track("sub") == 0) then
            msg = ("Subtitle" .. " [" .. get_track("sub") .. "∕" .. #tracks_osc.sub .. "] ")

            local prop = mp.get_property("current-tracks/sub/lang")
            if not prop then
                prop = "N/A"
            end
            msg = msg .. "(" .. prop .. ")"

            prop = mp.get_property("current-tracks/sub/title")
            if prop then
                msg = msg .. " " .. prop
            end
            return msg
        end
        return msg
    end
    ne.eventresponder["mbtn_left_up"] =
        function () set_track("sub", 1) end
    ne.eventresponder["mbtn_right_up"] =
        function () set_track("sub", -1) end
    ne.eventresponder["shift+mbtn_left_down"] =
        function () show_message(get_tracklist("sub"), 2) end

    --tog_fs
    ne = new_element("tog_fs", "button")
    ne.content = function ()
        if (state.fullscreen) then
            return ("\xEE\xA4\x93")
        else
            return ("\xEE\xA4\x92")
        end
    end
    ne.eventresponder["mbtn_left_up"] =
        function () mp.commandv("cycle", "fullscreen") end

    --tog_info
    ne = new_element("tog_info", "button")
    ne.content = "\xEE\xA4\x91"
    ne.eventresponder["mbtn_left_up"] =
        function () mp.commandv("script-binding", "stats/display-stats-toggle") end

    --seekbar
    ne = new_element("seekbar", "slider")

    ne.enabled = not (mp.get_property("percent-pos") == nil)
    state.slider_element = ne.enabled and ne or nil  -- used for forced_title
    ne.slider.markerF = function ()
        local duration = mp.get_property_number("duration", nil)
        if not (duration == nil) then
            local chapters = mp.get_property_native("chapter-list", {})
            local markers = {}
            for n = 1, #chapters do
                markers[n] = (chapters[n].time / duration * 100)
            end
            return markers
        else
            return {}
        end
    end
    ne.slider.posF =
        function () return mp.get_property_number("percent-pos", nil) end
    ne.slider.tooltipF = function (pos)
        local duration = mp.get_property_number("duration", nil)
        if not ((duration == nil) or (pos == nil)) then
            possec = duration * (pos / 100)
            return mp.format_time(possec)
        else
            return ""
        end
    end
    ne.slider.seekRangesF = function()
        if user_opts.seekrangestyle == "none" then
            return nil
        end
        local cache_state = state.cache_state
        if not cache_state then
            return nil
        end
        local duration = mp.get_property_number("duration", nil)
        if (duration == nil) or duration <= 0 then
            return nil
        end
        local ranges = cache_state["seekable-ranges"]
        if #ranges == 0 then
            return nil
        end
        local nranges = {}
        for _, range in pairs(ranges) do
            nranges[#nranges + 1] = {
                ["start"] = 100 * range["start"] / duration,
                ["end"] = 100 * range["end"] / duration,
            }
        end
        return nranges
    end
    ne.eventresponder["mouse_move"] = --keyframe seeking when mouse is dragged
        function (element)
            -- mouse move events may pile up during seeking and may still get
            -- sent when the user is done seeking, so we need to throw away
            -- identical seeks
            local seekto = get_slider_value(element)
            if (element.state.lastseek == nil) or
                (not (element.state.lastseek == seekto)) then
                    local flags = "absolute-percent"
                    if not user_opts.seekbarkeyframes then
                        flags = flags .. "+exact"
                    end
                    mp.commandv("seek", seekto, flags)
                    element.state.lastseek = seekto
            end

        end
    ne.eventresponder["mbtn_left_down"] = --exact seeks on single clicks
        function (element) mp.commandv("seek", get_slider_value(element),
            "absolute-percent", "exact") end
    ne.eventresponder["reset"] =
        function (element) element.state.lastseek = nil end


    -- tc_left (current pos)
    ne = new_element("tc_left", "button")

    ne.content = function ()
    if (state.tc_ms) then
        return (mp.get_property_osd("playback-time/full"))
    else
        return (mp.get_property_osd("playback-time"))
    end
    end
    ne.eventresponder["mbtn_left_up"] = function ()
        state.tc_ms = not state.tc_ms
        request_init()
    end

    -- tc_right (total/remaining time)
    ne = new_element("tc_right", "button")

    ne.visible = (mp.get_property_number("duration", 0) > 0)
    ne.content = function ()
        if (state.rightTC_trem) then
            if state.tc_ms then
                return ("-"..mp.get_property_osd("playtime-remaining/full"))
            else
                return ("-"..mp.get_property_osd("playtime-remaining"))
            end
        else
            if state.tc_ms then
                return (mp.get_property_osd("duration/full"))
            else
                return (mp.get_property_osd("duration"))
            end
        end
    end
    ne.eventresponder["mbtn_left_up"] =
        function () state.rightTC_trem = not state.rightTC_trem end

    -- cache
    ne = new_element("cache", "button")

    ne.content = function ()
        local cache_state = state.cache_state
        if not (cache_state and cache_state["seekable-ranges"] and
            #cache_state["seekable-ranges"] > 0) then
            -- probably not a network stream
            return ""
        end
        local dmx_cache = cache_state and cache_state["cache-duration"]
        local thresh = math.min(state.dmx_cache * 0.05, 5)  -- 5% or 5s
        if dmx_cache and math.abs(dmx_cache - state.dmx_cache) >= thresh then
            state.dmx_cache = dmx_cache
        else
            dmx_cache = state.dmx_cache
        end
        local min = math.floor(dmx_cache / 60)
        local sec = math.floor(dmx_cache % 60) -- don't round e.g. 59.9 to 60
        return "Cache: " .. (min > 0 and
            string.format("%sm%02.0fs", min, sec) or
            string.format("%3.0fs", sec))
    end

    -- volume
    ne = new_element("volume", "button")

    ne.content = function()
        local volume = mp.get_property_number("volume", 0)
        local mute = mp.get_property_native("mute")
        local volicon = {"\xEE\xA4\x86", "\xEE\xA4\x87", "\xEE\xA4\x88"}
        if volume == 0 or mute then
            return "\xEE\xA4\x85"
        else
            return volicon[math.min(3,math.ceil(volume / (100/3)))]
        end
    end
    ne.eventresponder["mbtn_left_up"] =
        function () mp.commandv("cycle", "mute") end

    ne.eventresponder["wheel_up_press"] =
        function () mp.commandv("osd-auto", "add", "volume", 5) end
    ne.eventresponder["wheel_down_press"] =
        function () mp.commandv("osd-auto", "add", "volume", -5) end


    -- load layout
    layouts()

    -- load window controls
    if window_controls_enabled() then
        window_controls()
    end

    --do something with the elements
    prepare_elements()
end

function shutdown()

end

--
-- Other important stuff
--


function show_osc()
    -- show when disabled can happen (e.g. mouse_move) due to async/delayed unbinding
    if not state.enabled then return end

    msg.trace("show_osc")
    --remember last time of invocation (mouse move)
    state.showtime = mp.get_time()

    osc_visible(true)

    if (user_opts.fadeduration > 0) then
        state.anitype = nil
    end
end

function hide_osc()
    msg.trace("hide_osc")
    if not state.enabled then
        -- typically hide happens at render() from tick(), but now tick() is
        -- no-op and won't render again to remove the osc, so do that manually.
        state.osc_visible = false
        render_wipe()
    elseif (user_opts.fadeduration > 0) then
        if not(state.osc_visible == false) then
            state.anitype = "out"
            request_tick()
        end
    else
        osc_visible(false)
    end
end

function osc_visible(visible)
    if state.osc_visible ~= visible then
        state.osc_visible = visible
    end
    request_tick()
end

function pause_state(name, enabled)
    state.paused = enabled
    mp.add_timeout(0.1, function() state.osd:update() end)
    if user_opts.showonpause then
        if enabled then
            state.lastvisibility = user_opts.visibility
            visibility_mode("always", true)
            show_osc()
        else
            visibility_mode(state.lastvisibility, true)
        end
    end
    request_tick()
end

function cache_state(name, st)
    state.cache_state = st
    request_tick()
end

-- Request that tick() is called (which typically re-renders the OSC).
-- The tick is then either executed immediately, or rate-limited if it was
-- called a small time ago.
function request_tick()
    if state.tick_timer == nil then
        state.tick_timer = mp.add_timeout(0, tick)
    end

    if not state.tick_timer:is_enabled() then
        local now = mp.get_time()
        local timeout = tick_delay - (now - state.tick_last_time)
        if timeout < 0 then
            timeout = 0
        end
        state.tick_timer.timeout = timeout
        state.tick_timer:resume()
    end
end

function mouse_leave()
    if get_hidetimeout() >= 0 then
        hide_osc()
    end
    -- reset mouse position
    state.last_mouseX, state.last_mouseY = nil, nil
    state.mouse_in_window = false
end

function request_init()
    state.initREQ = true
    request_tick()
end

-- Like request_init(), but also request an immediate update
function request_init_resize()
    request_init()
    -- ensure immediate update
    state.tick_timer:kill()
    state.tick_timer.timeout = 0
    state.tick_timer:resume()
end

function render_wipe()
    msg.trace("render_wipe()")
    state.osd.data = "" -- allows set_osd to immediately update on enable
    state.osd:remove()
end

function render()
    msg.trace("rendering")
    local current_screen_sizeX, current_screen_sizeY, aspect = mp.get_osd_size()
    local mouseX, mouseY = get_virt_mouse_pos()
    local now = mp.get_time()

    -- check if display changed, if so request reinit
    if not (state.mp_screen_sizeX == current_screen_sizeX
        and state.mp_screen_sizeY == current_screen_sizeY) then

        request_init_resize()

        state.mp_screen_sizeX = current_screen_sizeX
        state.mp_screen_sizeY = current_screen_sizeY
    end

    -- init management
    if state.active_element then
        -- mouse is held down on some element - keep ticking and igore initReq
        -- till it's released, or else the mouse-up (click) will misbehave or
        -- get ignored. that's because osc_init() recreates the osc elements,
        -- but mouse handling depends on the elements staying unmodified
        -- between mouse-down and mouse-up (using the index active_element).
        request_tick()
    elseif state.initREQ then
        osc_init()
        state.initREQ = false

        -- store initial mouse position
        if (state.last_mouseX == nil or state.last_mouseY == nil)
            and not (mouseX == nil or mouseY == nil) then

            state.last_mouseX, state.last_mouseY = mouseX, mouseY
        end
    end


    -- fade animation
    if not(state.anitype == nil) then

        if (state.anistart == nil) then
            state.anistart = now
        end

        if (now < state.anistart + (user_opts.fadeduration/1000)) then

            if (state.anitype == "in") then --fade in
                osc_visible(true)
                state.animation = scale_value(state.anistart,
                    (state.anistart + (user_opts.fadeduration/1000)),
                    255, 0, now)
            elseif (state.anitype == "out") then --fade out
                state.animation = scale_value(state.anistart,
                    (state.anistart + (user_opts.fadeduration/1000)),
                    0, 255, now)
            end

        else
            if (state.anitype == "out") then
                osc_visible(false)
            end
            kill_animation()
        end
    else
        kill_animation()
    end

    --mouse show/hide area
    for k,cords in pairs(osc_param.areas["showhide"]) do
        set_virt_mouse_area(cords.x1, cords.y1, cords.x2, cords.y2, "showhide")
    end
    if osc_param.areas["showhide_wc"] then
        for k,cords in pairs(osc_param.areas["showhide_wc"]) do
            set_virt_mouse_area(cords.x1, cords.y1, cords.x2, cords.y2, "showhide_wc")
        end
    else
        set_virt_mouse_area(0, 0, 0, 0, "showhide_wc")
    end
    do_enable_keybindings()

    --mouse input area
    local mouse_over_osc = false

    for _,cords in ipairs(osc_param.areas["input"]) do
        if state.osc_visible then -- activate only when OSC is actually visible
            set_virt_mouse_area(cords.x1, cords.y1, cords.x2, cords.y2, "input")
        end
        if state.osc_visible ~= state.input_enabled then
            if state.osc_visible then
                mp.enable_key_bindings("input")
            else
                mp.disable_key_bindings("input")
            end
            state.input_enabled = state.osc_visible
        end

        if (mouse_hit_coords(cords.x1, cords.y1, cords.x2, cords.y2)) then
            mouse_over_osc = true
        end
    end

    if osc_param.areas["window-controls"] then
        for _,cords in ipairs(osc_param.areas["window-controls"]) do
            if state.osc_visible then -- activate only when OSC is actually visible
                set_virt_mouse_area(cords.x1, cords.y1, cords.x2, cords.y2, "window-controls")
                mp.enable_key_bindings("window-controls")
            else
                mp.disable_key_bindings("window-controls")
            end

            if (mouse_hit_coords(cords.x1, cords.y1, cords.x2, cords.y2)) then
                mouse_over_osc = true
            end
        end
    end

    if osc_param.areas["window-controls-title"] then
        for _,cords in ipairs(osc_param.areas["window-controls-title"]) do
            if (mouse_hit_coords(cords.x1, cords.y1, cords.x2, cords.y2)) then
                mouse_over_osc = true
            end
        end
    end

    -- autohide
    if not (state.showtime == nil) and (get_hidetimeout() >= 0) then
        local timeout = state.showtime + (get_hidetimeout()/1000) - now
        if timeout <= 0 then
            if (state.active_element == nil) and not (mouse_over_osc) then
                hide_osc()
            end
        else
            -- the timer is only used to recheck the state and to possibly run
            -- the code above again
            if not state.hide_timer then
                state.hide_timer = mp.add_timeout(0, tick)
            end
            state.hide_timer.timeout = timeout
            -- re-arm
            state.hide_timer:kill()
            state.hide_timer:resume()
        end
    end


    -- actual rendering
    local ass = assdraw.ass_new()

    -- Messages
    render_message(ass)

    -- mpv_thumbnail_script.lua --
    local thumb_was_visible = osc_thumb_state.visible
    osc_thumb_state.visible = false
    -- // mpv_thumbnail_script.lua // --

    -- actual OSC
    if state.osc_visible then
        render_elements(ass)
    end

    -- mpv_thumbnail_script.lua --
    if not osc_thumb_state.visible and thumb_was_visible then
        hide_thumbnail()
    end
    -- // mpv_thumbnail_script.lua // --

    -- submit
    set_osd(osc_param.playresy * osc_param.display_aspect,
            osc_param.playresy, ass.text)
end

--
-- Eventhandling
--

local function element_has_action(element, action)
    return element and element.eventresponder and
        element.eventresponder[action]
end

function process_event(source, what)
    local action = string.format("%s%s", source,
        what and ("_" .. what) or "")

    if what == "down" or what == "press" then

        for n = 1, #elements do

            if mouse_hit(elements[n]) and
                elements[n].eventresponder and
                (elements[n].eventresponder[source .. "_up"] or
                    elements[n].eventresponder[action]) then

                if what == "down" then
                    state.active_element = n
                    state.active_event_source = source
                end
                -- fire the down or press event if the element has one
                if element_has_action(elements[n], action) then
                    elements[n].eventresponder[action](elements[n])
                end

            end
        end

    elseif what == "up" then

        if elements[state.active_element] then
            local n = state.active_element

            if n == 0 then
                --click on background (does not work)
            elseif element_has_action(elements[n], action) and
                mouse_hit(elements[n]) then

                elements[n].eventresponder[action](elements[n])
            end

            --reset active element
            if element_has_action(elements[n], "reset") then
                elements[n].eventresponder["reset"](elements[n])
            end

        end
        state.active_element = nil
        state.mouse_down_counter = 0

    elseif source == "mouse_move" then

        state.mouse_in_window = true

        local mouseX, mouseY = get_virt_mouse_pos()
        if (user_opts.minmousemove == 0) or
            (not ((state.last_mouseX == nil) or (state.last_mouseY == nil)) and
                ((math.abs(mouseX - state.last_mouseX) >= user_opts.minmousemove)
                    or (math.abs(mouseY - state.last_mouseY) >= user_opts.minmousemove)
                )
            ) then
            show_osc()
        end
        state.last_mouseX, state.last_mouseY = mouseX, mouseY

        local n = state.active_element
        if element_has_action(elements[n], action) then
            elements[n].eventresponder[action](elements[n])
        end
    end

    -- ensure rendering after any (mouse) event - icons could change etc
    request_tick()
end


local logo_lines = {
    -- White border
    "{\\c&HE5E5E5&\\p6}m 895 10 b 401 10 0 410 0 905 0 1399 401 1800 895 1800 1390 1800 1790 1399 1790 905 1790 410 1390 10 895 10 {\\p0}",
    -- Purple fill
    "{\\c&H682167&\\p6}m 925 42 b 463 42 87 418 87 880 87 1343 463 1718 925 1718 1388 1718 1763 1343 1763 880 1763 418 1388 42 925 42{\\p0}",
    -- Darker fill
    "{\\c&H430142&\\p6}m 1605 828 b 1605 1175 1324 1456 977 1456 631 1456 349 1175 349 828 349 482 631 200 977 200 1324 200 1605 482 1605 828{\\p0}",
    -- White fill
    "{\\c&HDDDBDD&\\p6}m 1296 910 b 1296 1131 1117 1310 897 1310 676 1310 497 1131 497 910 497 689 676 511 897 511 1117 511 1296 689 1296 910{\\p0}",
    -- Triangle
    "{\\c&H691F69&\\p6}m 762 1113 l 762 708 b 881 776 1000 843 1119 911 1000 978 881 1046 762 1113{\\p0}",
}

local santa_hat_lines = {
    -- Pompoms
    "{\\c&HC0C0C0&\\p6}m 500 -323 b 491 -322 481 -318 475 -311 465 -312 456 -319 446 -318 434 -314 427 -304 417 -297 410 -290 404 -282 395 -278 390 -274 387 -267 381 -265 377 -261 379 -254 384 -253 397 -244 409 -232 425 -228 437 -228 446 -218 457 -217 462 -216 466 -213 468 -209 471 -205 477 -203 482 -206 491 -211 499 -217 508 -222 532 -235 556 -249 576 -267 584 -272 584 -284 578 -290 569 -305 550 -312 533 -309 523 -310 515 -316 507 -321 505 -323 503 -323 500 -323{\\p0}",
    "{\\c&HE0E0E0&\\p6}m 315 -260 b 286 -258 259 -240 246 -215 235 -210 222 -215 211 -211 204 -188 177 -176 172 -151 170 -139 163 -128 154 -121 143 -103 141 -81 143 -60 139 -46 125 -34 129 -17 132 -1 134 16 142 30 145 56 161 80 181 96 196 114 210 133 231 144 266 153 303 138 328 115 373 79 401 28 423 -24 446 -73 465 -123 483 -174 487 -199 467 -225 442 -227 421 -232 402 -242 384 -254 364 -259 342 -250 322 -260 320 -260 317 -261 315 -260{\\p0}",
    -- Main cap
    "{\\c&H0000F0&\\p6}m 1151 -523 b 1016 -516 891 -458 769 -406 693 -369 624 -319 561 -262 526 -252 465 -235 479 -187 502 -147 551 -135 588 -111 1115 165 1379 232 1909 761 1926 800 1952 834 1987 858 2020 883 2053 912 2065 952 2088 1000 2146 962 2139 919 2162 836 2156 747 2143 662 2131 615 2116 567 2122 517 2120 410 2090 306 2089 199 2092 147 2071 99 2034 64 1987 5 1928 -41 1869 -86 1777 -157 1712 -256 1629 -337 1578 -389 1521 -436 1461 -476 1407 -509 1343 -507 1284 -515 1240 -519 1195 -521 1151 -523{\\p0}",
    -- Cap shadow
    "{\\c&H0000AA&\\p6}m 1657 248 b 1658 254 1659 261 1660 267 1669 276 1680 284 1689 293 1695 302 1700 311 1707 320 1716 325 1726 330 1735 335 1744 347 1752 360 1761 371 1753 352 1754 331 1753 311 1751 237 1751 163 1751 90 1752 64 1752 37 1767 14 1778 -3 1785 -24 1786 -45 1786 -60 1786 -77 1774 -87 1760 -96 1750 -78 1751 -65 1748 -37 1750 -8 1750 20 1734 78 1715 134 1699 192 1694 211 1689 231 1676 246 1671 251 1661 255 1657 248 m 1909 541 b 1914 542 1922 549 1917 539 1919 520 1921 502 1919 483 1918 458 1917 433 1915 407 1930 373 1942 338 1947 301 1952 270 1954 238 1951 207 1946 214 1947 229 1945 239 1939 278 1936 318 1924 356 1923 362 1913 382 1912 364 1906 301 1904 237 1891 175 1887 150 1892 126 1892 101 1892 68 1893 35 1888 2 1884 -9 1871 -20 1859 -14 1851 -6 1854 9 1854 20 1855 58 1864 95 1873 132 1883 179 1894 225 1899 273 1908 362 1910 451 1909 541{\\p0}",
    -- Brim and tip pompom
    "{\\c&HF8F8F8&\\p6}m 626 -191 b 565 -155 486 -196 428 -151 387 -115 327 -101 304 -47 273 2 267 59 249 113 219 157 217 213 215 265 217 309 260 302 285 283 373 264 465 264 555 257 608 252 655 292 709 287 759 294 816 276 863 298 903 340 972 324 1012 367 1061 394 1125 382 1167 424 1213 462 1268 482 1322 506 1385 546 1427 610 1479 662 1510 690 1534 725 1566 752 1611 796 1664 830 1703 880 1740 918 1747 986 1805 1005 1863 991 1897 932 1916 880 1914 823 1945 777 1961 725 1979 673 1957 622 1938 575 1912 534 1862 515 1836 473 1790 417 1755 351 1697 305 1658 266 1633 216 1593 176 1574 138 1539 116 1497 110 1448 101 1402 77 1371 37 1346 -16 1295 15 1254 6 1211 -27 1170 -62 1121 -86 1072 -104 1027 -128 976 -133 914 -130 851 -137 794 -162 740 -181 679 -168 626 -191 m 2051 917 b 1971 932 1929 1017 1919 1091 1912 1149 1923 1214 1970 1254 2000 1279 2027 1314 2066 1325 2139 1338 2212 1295 2254 1238 2281 1203 2287 1158 2282 1116 2292 1061 2273 1006 2229 970 2206 941 2167 938 2138 918{\\p0}",
}

-- called by mpv on every frame
function tick()
    if (not state.enabled) then return end

    if (state.idle) then

        -- render idle message
        msg.trace("idle message")
        local icon_x, icon_y = 320 - 26, 140
        local line_prefix = ("{\\rDefault\\an7\\1a&H00&\\bord0\\shad0\\pos(%f,%f)}"):format(icon_x, icon_y)

        local ass = assdraw.ass_new()
        -- mpv logo
        for i, line in ipairs(logo_lines) do
            ass:new_event()
            ass:append(line_prefix .. line)
        end

        -- Santa hat
        if is_december and not user_opts.greenandgrumpy then
            for i, line in ipairs(santa_hat_lines) do
                ass:new_event()
                ass:append(line_prefix .. line)
            end
        end

        ass:new_event()
        ass:pos(320, icon_y+65)
        ass:an(8)
        ass:append("Drop files or URLs to play here.")
        set_osd(640, 360, ass.text)

        if state.showhide_enabled then
            mp.disable_key_bindings("showhide")
            mp.disable_key_bindings("showhide_wc")
            state.showhide_enabled = false
        end


    elseif (state.fullscreen and user_opts.showfullscreen)
        or (not state.fullscreen and user_opts.showwindowed) then

        -- render the OSC
        render()
    else
        -- Flush OSD
        render_wipe()
    end

    state.tick_last_time = mp.get_time()

    if state.anitype ~= nil then
        -- state.anistart can be nil - animation should now start, or it can
        -- be a timestamp when it started. state.idle has no animation.
        if not state.idle and
           (not state.anistart or
            mp.get_time() < 1 + state.anistart + user_opts.fadeduration/1000)
        then
            -- animating or starting, or still within 1s past the deadline
            request_tick()
        else
            kill_animation()
        end
    end
end

function do_enable_keybindings()
    if state.enabled then
        if not state.showhide_enabled then
            mp.enable_key_bindings("showhide", "allow-vo-dragging+allow-hide-cursor")
            mp.enable_key_bindings("showhide_wc", "allow-vo-dragging+allow-hide-cursor")
        end
        state.showhide_enabled = true
    end
end

function enable_osc(enable)
    state.enabled = enable
    if enable then
        do_enable_keybindings()
    else
        hide_osc() -- acts immediately when state.enabled == false
        if state.showhide_enabled then
            mp.disable_key_bindings("showhide")
            mp.disable_key_bindings("showhide_wc")
        end
        state.showhide_enabled = false
    end
end

-- duration is observed for the sole purpose of updating chapter markers
-- positions. live streams with chapters are very rare, and the update is also
-- expensive (with request_init), so it's only observed when we have chapters
-- and the user didn't disable the livemarkers option (update_duration_watch).
function on_duration() request_init() end

local duration_watched = false
function update_duration_watch()
    local want_watch = user_opts.livemarkers and
                       (mp.get_property_number("chapters", 0) or 0) > 0 and
                       true or false  -- ensure it's a boolean

    if (want_watch ~= duration_watched) then
        if want_watch then
            mp.observe_property("duration", nil, on_duration)
        else
            mp.unobserve_property(on_duration)
        end
        duration_watched = want_watch
    end
end

-- mpv_thumbnail_script.lua --

local builtin_osc_enabled = mp.get_property_native('osc')
if builtin_osc_enabled then
    local err = "You must disable the built-in OSC with osc=no in your configuration!"
    mp.osd_message(err, 5)
    msg.error(err)

    -- This may break, but since we can, let's try to just disable the builtin OSC.
    mp.set_property_native('osc', false)
end

-- // mpv_thumbnail_script.lua // --

validate_user_opts()
update_duration_watch()

mp.register_event("shutdown", shutdown)
mp.register_event("start-file", request_init)
mp.observe_property("track-list", nil, request_init)
mp.observe_property("playlist", nil, request_init)
mp.observe_property("chapter-list", nil, function()
    update_duration_watch()
    request_init()
end)

mp.register_script_message("osc-message", show_message)
mp.register_script_message("osc-chapterlist", function(dur)
    show_message(get_chapterlist(), dur)
end)
mp.register_script_message("osc-playlist", function(dur)
    show_message(get_playlist(), dur)
end)
mp.register_script_message("osc-tracklist", function(dur)
    local msg = {}
    for k,v in pairs(nicetypes) do
        table.insert(msg, get_tracklist(k))
    end
    show_message(table.concat(msg, '\n\n'), dur)
end)

mp.observe_property("fullscreen", "bool",
    function(name, val)
        state.fullscreen = val
        request_init_resize()
    end
)
mp.observe_property("border", "bool",
    function(name, val)
        state.border = val
        request_init_resize()
    end
)
mp.observe_property("window-maximized", "bool",
    function(name, val)
        state.maximized = val
        request_init_resize()
    end
)
mp.observe_property("idle-active", "bool",
    function(name, val)
        state.idle = val
        request_tick()
    end
)
mp.observe_property("pause", "bool", pause_state)
mp.observe_property("demuxer-cache-state", "native", cache_state)
mp.observe_property("vo-configured", "bool", function(name, val)
    request_tick()
end)
mp.observe_property("playback-time", "number", function(name, val)
    request_tick()
end)
mp.observe_property("osd-dimensions", "native", function(name, val)
    -- (we could use the value instead of re-querying it all the time, but then
    --  we might have to worry about property update ordering)
    request_init_resize()
end)

-- mouse show/hide bindings
mp.set_key_bindings({
    {"mouse_move",              function(e) process_event("mouse_move", nil) end},
    {"mouse_leave",             mouse_leave},
}, "showhide", "force")
mp.set_key_bindings({
    {"mouse_move",              function(e) process_event("mouse_move", nil) end},
    {"mouse_leave",             mouse_leave},
}, "showhide_wc", "force")
do_enable_keybindings()

--mouse input bindings
mp.set_key_bindings({
    {"mbtn_left",           function(e) process_event("mbtn_left", "up") end,
                            function(e) process_event("mbtn_left", "down")  end},
    {"shift+mbtn_left",     function(e) process_event("shift+mbtn_left", "up") end,
                            function(e) process_event("shift+mbtn_left", "down")  end},
    {"mbtn_right",          function(e) process_event("mbtn_right", "up") end,
                            function(e) process_event("mbtn_right", "down")  end},
    -- alias to shift_mbtn_left for single-handed mouse use
    {"mbtn_mid",            function(e) process_event("shift+mbtn_left", "up") end,
                            function(e) process_event("shift+mbtn_left", "down")  end},
    {"wheel_up",            function(e) process_event("wheel_up", "press") end},
    {"wheel_down",          function(e) process_event("wheel_down", "press") end},
    {"mbtn_left_dbl",       "ignore"},
    {"shift+mbtn_left_dbl", "ignore"},
    {"mbtn_right_dbl",      "ignore"},
}, "input", "force")
mp.enable_key_bindings("input")

mp.set_key_bindings({
    {"mbtn_left",           function(e) process_event("mbtn_left", "up") end,
                            function(e) process_event("mbtn_left", "down")  end},
}, "window-controls", "force")
mp.enable_key_bindings("window-controls")

function get_hidetimeout()
    if user_opts.visibility == "always" then
        return -1 -- disable autohide
    end
    return user_opts.hidetimeout
end

function always_on(val)
    if state.enabled then
        if val then
            show_osc()
        else
            hide_osc()
        end
    end
end

-- mode can be auto/always/never/cycle
-- the modes only affect internal variables and not stored on its own.
function visibility_mode(mode, no_osd)
    if mode == "cycle" then
        if not state.enabled then
            mode = "auto"
        elseif user_opts.visibility ~= "always" then
            mode = "always"
        else
            mode = "never"
        end
    end

    if mode == "auto" then
        always_on(false)
        enable_osc(true)
    elseif mode == "always" then
        enable_osc(true)
        always_on(true)
    elseif mode == "never" then
        enable_osc(false)
    else
        msg.warn("Ignoring unknown visibility mode '" .. mode .. "'")
        return
    end

    user_opts.visibility = mode
    utils.shared_script_property_set("osc-visibility", mode)

    if not no_osd and tonumber(mp.get_property("osd-level")) >= 1 then
        mp.osd_message("OSC visibility: " .. mode)
    end

    -- Reset the input state on a mode change. The input state will be
    -- recalcuated on the next render cycle, except in 'never' mode where it
    -- will just stay disabled.
    mp.disable_key_bindings("input")
    mp.disable_key_bindings("window-controls")
    state.input_enabled = false

    request_tick()
end

visibility_mode(user_opts.visibility, true)
mp.register_script_message("osc-visibility", visibility_mode)
mp.add_key_binding(nil, "visibility", function() visibility_mode("cycle") end)

set_virt_mouse_area(0, 0, 0, 0, "input")
set_virt_mouse_area(0, 0, 0, 0, "window-controls")
