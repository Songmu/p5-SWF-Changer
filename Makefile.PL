use inc::Module::Install;
name 'SWF-Builder';
all_from 'lib/SWF/Builder.pm';

res_external_bin 'swfmill';

requires 'IPC::Run';
requires 'XML::LibXML';
requires 'Imager';
requires 'Math::Round';
requires 'Compress::Zlib';
requires 'MIME::Base64';

tests 't/*.t';
author_tests 'xt';

test_requires 'Test::More';
auto_set_repository;
auto_include;
WriteAll;
