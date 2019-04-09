/*
 * Copyright 2019 Volvo Cars
 *
 * Licensed to the Apache Software Foundation (ASF) under one
 * or more contributor license agreements.  See the NOTICE file
 * distributed with this work for additional information
 * regarding copyright ownership.  The ASF licenses this file
 * to you under the Apache License, Version 2.0 (the
 * ”License"); you may not use this file except in compliance
 * with the License.  You may obtain a copy of the License at
 *
 *  http://www.apache.org/licenses/LICENSE-2.0
 *
 * Unless required by applicable law or agreed to in writing,
 * software distributed under the License is distributed on an
 * “AS IS" BASIS, WITHOUT WARRANTIES OR CONDITIONS OF ANY
 * KIND, either express or implied.  See the License for the
 * specific language governing permissions and limitations
 * under the License.
 */

// cc -o powertrain powertrain.c -lcsunixds
#include <csunixds.h>
#include <stdio.h>
#include <assert.h>

#define NAME_COUNT (sizeof(names) / sizeof(names[0]))

static const char *const names[] = {
	"PropulsionCANhs:VehSpdLgtSafe",
};

int main(int argc, char *argv[]) {
	assert(cs_initialize(NULL) == CS_OK);

	cs_value_t values[NAME_COUNT];
	assert(cs_read(NAME_COUNT, names, values) == CS_OK);

	int i;
	for (i=0; i<NAME_COUNT; i++) {
		printf("%4s %-45s : %7.7f\n",
				values[i].value_f64 != 0.0 ? "-->" : "",
				names[i],
				values[i].value_f64
				);
	}

	assert(cs_shutdown() == CS_OK);
	return 0;
}
