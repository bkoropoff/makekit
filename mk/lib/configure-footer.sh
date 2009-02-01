mk_log "Creating ${MK_CONFIG_FILENAME}"
# Open config file
exec 4>${MK_CONFIG_FILE}

for __var in ${MK_DEFINE_LIST}
do
    __stmt="echo \"\$${__var}\""
    __val="`eval "$__stmt"`"
    echo "$__var=`mk_quote "$__val"`" >&4
done

echo "MK_EXPORT_LIST='`echo "${MK_EXPORT_LIST}" | sed -e 's/  *//' -e 's/^ //' -e 's/ $//'`'" >&4

# Close config file
exec 4>&-

mk_log "Creating ${MK_MAKEFILE_FILENAME}"
# Open up Makefile
exec 4>"${MK_MAKEFILE_FILE}"

# Write basic Makefile variables
mk_make_define MK_ROOT_DIR "${MK_ROOT_DIR}"
mk_make_define MK_WORK_DIR "${MK_WORK_DIR}"
mk_make_define ACTION      "\$(MK_WORK_DIR)/${MK_ACTION_FILENAME} --make \"\$(MAKE)\""
mk_make_define MK_CONFIGURE_ARGS "${MK_CONFIGURE_ARGS}"

# Decide if resources are present
if [ -d "${MK_RESOURCE_DIR}" ]
then
    MK_RESOURCE_YES=""
    MK_RESOURCE_NO="#"
else
    MK_RESOURCE_YES="#"
    MK_RESOURCE_NO=""
fi

echo "" >&4
sed \
    -e "s:@MK_WORK_DIR@:${MK_WORK_DIR}:g" \
    -e "s:@MK_RESOURCE_YES@:${MK_RESOURCE_YES}:g" \
    -e "s:@MK_RESOURCE_NO@:${MK_RESOURCE_NO}:g" \
    < "${MK_ROOT_DIR}/${MK_MAKEFILE_FILENAME}.in" >&4

# Close Makefile
exec 4>&-

mk_log "Creating ${MK_ACTION_FILENAME}"
# Open up action file
exec 4>"${MK_ACTION_FILE}"

echo "#!${MK_SHELL}" >&4
echo "MK_ROOT_DIR='${MK_ROOT_DIR}'" >&4
echo "MK_WORK_DIR='${MK_WORK_DIR}'" >&4

cat "${MK_ROOT_DIR}/${MK_ACTION_FILENAME}.in" >&4

# Close action file
exec 4>&-

# Set action file executable
chmod +x "${MK_ACTION_FILE}"

# Set up basic directory structure
for dir in ${MK_TARGET_DIRNAME} ${MK_BUILD_DIRNAME} ${MK_STAGE_DIRNAME} ${MK_DIST_DIRNAME}
do
    mk_log "Creating directory ${dir}"
    mkdir -p "${MK_WORK_DIR}/${dir}"
done
