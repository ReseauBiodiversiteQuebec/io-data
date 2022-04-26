import pystac
import os
from urllib.parse import urlparse
from datetime import datetime
import tempfile
from pathlib import Path
import urllib.request
import sys
sys.path.append('/bqio/')
import tif2cog
import stac_item
from s3io import upload_tiff_to_io
from s3io import upload_stac_to_io


catalog = pystac.Catalog.from_file(os.path.join("/bqio/stac11b/","catalog.json"))
spatial_extent = pystac.SpatialExtent(bboxes=[[-81.68, -4.24, -66.55, 12.90]])
temporal_extent = pystac.TemporalExtent(intervals=[[datetime.fromisoformat("2000-01-01"),datetime.fromisoformat("2020-12-31")]])
collection_extent = pystac.Extent(spatial=spatial_extent, temporal=temporal_extent)
collection_id = 'colombia-lc'
collection = pystac.Collection(id=collection_id,
							   title='Colombia Land Cover - 30m',
                               description='A raster representation of the Colombian land cover data',
                               extent=collection_extent,
                               license='CC-BY-SA-4.0',
                               href=collection_id)


try:
	temp_output_path = (Path(tempfile.gettempdir()) / next(tempfile._get_candidate_names())).with_suffix(".tif")
	tif2cog.tif2cog([Path('/bqio/colombia-lc/colombia_cobertura_tierra_2000_2002.tif')], temp_output_path, "raw")
	tif_url = upload_tiff_to_io(str(temp_output_path), 'colombia_cobertura_tierra_2000_2002.tif', "COLOMBIA-LC")
	properties = {
		'description': 'Colombia Land Cover - 30m - 2000-2002',
		'year': '2010-2012'
	}
	item = stac_item.stac_create_item(str(temp_output_path), tif_url, 'COLOMBIA-LC', datetime.fromisoformat('2000-01-01'), collection, properties)
	collection.add_item(item)
	os.remove(temp_output_path)
except (RuntimeError, TypeError, NameError) as err:
	print("Oops!  There was an error creating the COG -" + format(err))


try:
	temp_output_path = (Path(tempfile.gettempdir()) / next(tempfile._get_candidate_names())).with_suffix(".tif")
	tif2cog.tif2cog([Path('/bqio/colombia-lc/colombia_cobertura_tierra_2005_2009.tif')], temp_output_path, "raw")
	tif_url = upload_tiff_to_io(str(temp_output_path), 'colombia_cobertura_tierra_2005_2009.tif', "COLOMBIA-LC")
	properties = {
		'description': 'Colombia Land Cover - 30m - 2005-2009',
		'year': '2005-2009'
	}
	item = stac_item.stac_create_item(str(temp_output_path), tif_url, 'COLOMBIA-LC', datetime.fromisoformat('2005-01-01'), collection, properties)
	collection.add_item(item)
	os.remove(temp_output_path)
except (RuntimeError, TypeError, NameError) as err:
	print("Oops!  There was an error creating the COG -" + format(err))

try:
	temp_output_path = (Path(tempfile.gettempdir()) / next(tempfile._get_candidate_names())).with_suffix(".tif")
	tif2cog.tif2cog([Path('/bqio/colombia-lc/colombia_cobertura_tierra_2010_2012.tif')], temp_output_path, "raw")
	tif_url = upload_tiff_to_io(str(temp_output_path), 'colombia_cobertura_tierra_2010_2012.tif', "COLOMBIA-LC")
	properties = {
		'description': 'Colombia Land Cover - 30m - 2010-2012',
		'year': '2010-2012'
	}
	item = stac_item.stac_create_item(str(temp_output_path), tif_url, 'COLOMBIA-LC', datetime.fromisoformat('2010-01-01'), collection, properties)
	collection.add_item(item)
	os.remove(temp_output_path)
except (RuntimeError, TypeError, NameError) as err:
	print("Oops!  There was an error creating the COG -" + format(err))



try:
	temp_output_path = (Path(tempfile.gettempdir()) / next(tempfile._get_candidate_names())).with_suffix(".tif")
	tif2cog.tif2cog([Path('/bqio/colombia-lc/colombia_cobertura_tierra_2018.tif')], temp_output_path, "raw")
	tif_url = upload_tiff_to_io(str(temp_output_path), 'colombia_cobertura_tierra_2018.tif', "COLOMBIA-LC")
	properties = {
		'description': 'Colombia Land Cover - 30m - 2018',
		'year': '2018'
	}
	item = stac_item.stac_create_item(str(temp_output_path), tif_url, 'COLOMBIA-LC', datetime.fromisoformat('2018-01-01'), collection, properties)
	collection.add_item(item)
	os.remove(temp_output_path)
except (RuntimeError, TypeError, NameError) as err:
	print("Oops!  There was an error creating the COG -" + format(err))


catalog.add_child(collection)
catalog.normalize_hrefs(root_href="https://io.biodiversite-quebec.ca/stac/")
catalog.save(dest_href='/bqio/stac12/',catalog_type=pystac.CatalogType.SELF_CONTAINED)