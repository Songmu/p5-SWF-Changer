use inc::Module::Install;
name 'SWF-Builder';
all_from 'lib/SWF/Builder.pm';

# requires '';

tests 't/*.t';
author_tests 'xt';

test_requires 'Test::More';
auto_set_repository;
auto_include;
WriteAll;
